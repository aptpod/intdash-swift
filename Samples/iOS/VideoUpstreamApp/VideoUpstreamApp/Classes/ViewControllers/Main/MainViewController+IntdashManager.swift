//
//  MainViewController+IntdashManager.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import Intdash

extension MainViewController: IntdashClientDelegate, IntdashClientUpstreamManagerDelegate {

    //MARK:- IntdashClient
    public func openIntdashClient(completion: @escaping (Bool)->()) {
        guard let session = IntdashAPIManager.shared.session else {
            print("Failed to get session.")
            completion(false)
            return
        }

        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard self.intdashClient == nil else {
            print("Already used intdash client.")
            completion(false)
            return
        }
        
        // IntdashClient
        let client = IntdashClient()
        self.intdashClient = client
        client.session = session
        client.addDelegate(self)
        // セクション情報の管理を行います。
        client.upstreamManager.addDelegate(delegate: self)
        // intdashサーバーとの接続を開始する。
        client.connect { [weak self] (error) in
            guard error == nil else {
                print("Failed to connect intdash server. \(error!.localizedDescription)")
                completion(false)
                self?.connectionError()
                return
            }
            print("Success to connect intdash server.")
        }
    }
    
    //MARK:- IntdashClient
    public func startUpstream(completion: @escaping (Bool)->()) {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        
        guard let edgeUUID = IntdashAPIManager.shared.singInEdgeUuid else {
            print("Failed to get edge uuid.")
            return
        }
        
        // 前回使用したアップストリームIDが存在すればストリームを閉じる。
        let group = DispatchGroup()
        let streamIds = self.upstreamIds
        self.upstreamIds.removeAll()
        self.upstreamId = nil
        if streamIds.count > 0 {
            group.enter()
            // 開いているストリームIDを閉じる。
            client.upstreamManager.close(streamIds: streamIds) { (error) in
                if error != nil {
                    print("Failed to close intdash upstream. \(error!)")
                }
                client.upstreamManager.removeClosedUpstream()
            }
        }
        
        // 計測IDを取得する。
        client.upstreamManager.requestMeasurementId(edgeUuid: edgeUUID, completion: { [weak self] (measId, error) in
            guard error == nil, let upstreamMeasId = measId else {
                print("Failed to get measurement ID.")
                completion(false)
                self?.connectionError()
                return
            }
            print("MeasurementID: \(upstreamMeasId)")
            self?.upstreamMeasurementId = upstreamMeasId
            
            var streamId = 0
            do {
                // アップストリームを開く。
                streamId = try client.upstreamManager.open(measurementId: upstreamMeasId, srcEdgeId: edgeUUID, dstEdgeIds: nil, store: Config.INTDASH_IS_SAVE_TO_SERVER, retryCount: 0, sectionUpdateInterval: nil)
            } catch {
                print("Failed to open stream. \(error.localizedDescription)")
                completion(false)
                self?.connectionError()
                return
            }
            print("UpstreamID: \(streamId)")
            self?.upstreamIds.append(streamId)
            
            // アップストリーム情報をintdashサーバーと同期する。
            client.upstreamManager.sync(completion: { (error) in
                guard error == nil else {
                    print("Failed to request stream. \(error!.localizedDescription)")
                    completion(false)
                    self?.connectionError()
                    return
                }
                print("Success to open stream.")
                // サーバーへデータを保存する場合は`IntdashDataFileManager`を利用してローカルストレージへデータの保存も行い再送アップロードを行える状態にします。
                if Config.INTDASH_IS_SAVE_TO_SERVER {
                    do {
                        let fileManager = try IntdashDataFileManager(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(upstreamMeasId)")
                        try fileManager.setMeasurementId(id: upstreamMeasId)
                        self?.intdashDataFileManager = fileManager
                    } catch {
                        print("Failed to setup file manager. \(error)")
                    }
                }
                // ストリーム開始
                self?.upstreamId = streamId
                self?.refreshNetworkTimeCnt = 0
                self?.resetBaseTime()
                completion(true)
            })
        })
    }
    
    //MARK:- IntdashClientDelegate
    func intdashClientDidConnect(_ client: IntdashClient) {}
    
    func intdashClientDidDisconnect(_ client: IntdashClient) {}
    
    func intdashClient(_ client: IntdashClient, didFailWithError error: Error?) {}
    
    func intdashClient(_ client: IntdashClient, didRetryToRequestSpecs success: Bool) {}
    
    public func connectionError() {
        guard !self.isShowAlertDialog else { return }
        self.isShowAlertDialog = true
        AlertDialogView.showAlert(viewController: self, title: "Connection Error", message: "Failed to connect to the server.") { [weak self] in
            self?.isShowAlertDialog = false
            self?.app.signOut()
        }
    }
    
    func sendFirstData(timestamp: TimeInterval) {
        self.baseTime = timestamp
        if let streamId = self.upstreamId {
            do {
                // データ送信前の保存処理。
                try self.intdashDataFileManager?.setBaseTime(time: timestamp)
                /// ToDo
                /// チャンネルはストリームID毎に変更する事ができます。
                try self.intdashDataFileManager?.setStreamChannels(channels: Config.INTDASH_TARGET_CHANNEL)
                // 計測開始時間を送信します。
                try self.intdashClient?.upstreamManager.sendFirstData(timestamp, streamId: streamId, channelNum: Config.INTDASH_TARGET_CHANNEL)
                print("Success to send first data. \(timestamp)")
                // NTPと同期し正しい計測開始時間を再送信します。
                self.syncNTP(baseTime: timestamp, upstreamId: streamId)
            } catch {
                print("Failed to send first data.\(error)")
                // Close Intdash Client
                self.closeIntdashClient()
            }
        }
    }
    
    public func syncNTP(baseTime: TimeInterval, upstreamId: Int) {
        guard upstreamId != -1 else { return }
        // Sync NTP Clock
        DispatchQueue.global().async {
            MySystemClock.shared.updateNTPTime { (error) in
                guard error == nil else {
                    print("Failed to get offset between ntp and system clock. \(error!.localizedDescription)")
                    return
                }
                do {
                    let elapsedRtc = MySystemClock.shared.rtcDate.timeIntervalSince1970 - baseTime
                    let ntpTime = MySystemClock.shared.ntpDate.timeIntervalSince1970 - elapsedRtc
                    // 送信する`IntdashData`を生成します。`IntdashData.DataBaseTime`は基本的には後続のものが優先的に計測開始時間として取り扱われます。
                    let data = IntdashData.DataBaseTime.init(type: .ntp, baseTime: ntpTime)
                    // データ送信前の保存処理。
                    try self.intdashDataFileManager?.setBaseTime2(time: ntpTime)
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: 0, streamId: upstreamId)
                } catch {
                    print("Failed To Send NTP.\(error)")
                    // Close Intdash Client
                    self.closeIntdashClient()
                }
            }
        }
    }
    
    public func stopUpstream() {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        self.upstreamMeasurementId = ""
                
        // Duration
        let duration = MySystemClock.shared.rtcDate.timeIntervalSince1970-self.baseTime
        
        if let streamId = self.upstreamId {
            self.upstreamId = nil
            // `IntdashDataFileManager`に計測した期間を保存する事ができます。
            try? self.intdashDataFileManager?.setDuration(duration: duration)
            self.intdashDataFileManager = nil
            do {
                // 計測終了データを送信します。
                try client.upstreamManager.sendLastData(streamId: streamId)
            } catch {
                print("Failed to send last data. \(error)")
            }
        }
    }
    
    public func closeIntdashClient() {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        print("closeIntdashClient() >>>")
        self.intdashClient = nil
        
        DispatchQueue.global().async {
            let group = DispatchGroup()
            let streamIds = self.upstreamIds
            self.upstreamIds.removeAll()
            if streamIds.count > 0 {
                group.enter()
                // 開いているストリームIDを閉じる。
                client.upstreamManager.close(streamIds: streamIds) { (error) in
                    if error != nil {
                        print("Failed to close intdash upstream. \(error!)")
                    }
                    client.upstreamManager.removeClosedUpstream()
                    group.leave()
                }
            }
            
            group.notify(queue: .global()) {
                // intdashサーバーとの接続を解除します。
                client.disconnect(completion: { (error) in
                    if error != nil {
                        print("Failed to disconnect intdash server. \(error!)")
                    } else {
                        print("Success to disconnect intdash server.")
                    }
                    client.removeDelegate(self)
                })
            }
            print("<<< closeIntdashClient()")
        }
    }
    
    //MARK:- IntdashClientUpstreamManagerDelegate
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didGeneratedSesion sectionId: Int, sectionIndex: Int, streamId: Int, final: Bool, sentCount: Int, startOfElapsedTime: TimeInterval, endOfElapsedTime: TimeInterval) {
        print("didGeneratedSesion sectionId:\(sectionId), sectionIndex: \(sectionIndex), streamId:\(streamId), final:\(final), sentCount:\(sentCount), startOfElapsedTime:\(startOfElapsedTime), endOfElapsedTime:\(endOfElapsedTime) - IntdashClient.UpstreamManager")
        if final {
            // 最終データを受信(複数のストリームIDを用いている場合はカウンタなどを用いる)
            generateSendLastDataCnt += 1
        }
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
        print("didReceiveEndOfSection sectionId:\(sectionId), streamId:\(streamId), success:\(success), final:\(final), sentCount:\(sentCount) - IntdashClient.UpstreamManager")
        
        if final {
            generateSendLastDataCnt -= 1
            if generateSendLastDataCnt == 0 {
                // TODO: データの送信完了
                print("Completion of receiving final data. - IntdashClient.UpstreamManager")
            }
        }
        
        // 正しくAckが受信できなければintdashサーバーと再接続を行いキューに溜まるデータをクリアします。
        self.appendNetworkSectionTime(success: success)
    }
    
    func appendNetworkSectionTime(success: Bool) {
        guard !isRefreshingWebSocket else { return }
        self.badNetworkLock.lock()
        
        self.refreshNetworkTimeCnt += success ? -1 : 1
        if self.refreshNetworkTimeCnt < 0 {
            self.refreshNetworkTimeCnt = 0
        }
        if self.refreshNetworkTimeCnt > 0 {
            print("Network section clogged up.... count \(self.refreshNetworkTimeCnt)")
        }
        if self.refreshNetworkTimeCnt >= Config.BADNETWORK_REFRESH_TIME {
            if let client = self.intdashClient {
                isRefreshingWebSocket = true
                client.upstreamManager.reconnect { [weak self] _ in
                    self?.refreshNetworkTimeCnt = 0
                    self?.isRefreshingWebSocket = false
                    self?.badNetworkLock.unlock()
                }
            }
        }
        
        if !isRefreshingWebSocket {
            self.badNetworkLock.unlock()
        }
    }
}
