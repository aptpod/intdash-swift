//
//  MainViewController+IntdashManager.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import Intdash

extension MainViewController: IntdashClientDelegate, IntdashClientUpstreamManagerDelegate {

    //MARK:- IntdashClient
    public func openIntdashClient() {
        guard let session = IntdashAPIManager.shared.session else {
            connectionError("Failed to get session.")
            return
        }

        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard self.intdashClient == nil else {
            connectionError("Already used intdash client.")
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
                self?.connectionError("Failed to connect intdash server. \(error!.localizedDescription)")
                return
            }
            print("Success to connect intdash server.")
        }
    }
    
    func startUpstream(completion: @escaping (Bool)->()) {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        
        guard let edgeUUID = IntdashAPIManager.shared.singInEdgeUuid else {
            print("Failed to get edge uuid.")
            return
        }
        
        // 前回使用したアップストリームIDが存在すればストリームを閉じる。
        let streamIds = self.upstreamIds
        self.upstreamIds.removeAll()
        self.sensorUpstreamId = nil
        self.gpsUpstreamId = nil
        if streamIds.count > 0 {
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
                completion(false)
                self?.connectionError("Failed to get measurement ID.")
                return
            }
            print("MeasurementID: \(upstreamMeasId)")
            self?.upstreamMeasurementId = upstreamMeasId
            
            var sensorStreamId: Int? = nil
            if Config.SENSOR_IS_UPSTREAM {
                do {
                    // センサー用のアップストリームを開く。
                    sensorStreamId = try client.upstreamManager.open(measurementId: upstreamMeasId, srcEdgeId: edgeUUID, store: Config.INTDASH_IS_SAVE_TO_SERVER)
                } catch {
                    completion(false)
                    self?.connectionError("Failed to open stream. \(error.localizedDescription)")
                    return
                }
                print("Sensor UpstreamID: \(sensorStreamId!)")
                self?.upstreamIds.append(sensorStreamId!)
            }
            
            var gpsStreamId = 0
            do {
                // GPS用のアップストリームを開く。
                gpsStreamId = try client.upstreamManager.open(measurementId: upstreamMeasId, srcEdgeId: edgeUUID, store: Config.INTDASH_IS_SAVE_TO_SERVER)
            } catch {
                completion(false)
                self?.connectionError("Failed to open stream. \(error.localizedDescription)")
                return
            }
            print("GPS UpstreamID: \(gpsStreamId)")
            self?.upstreamIds.append(gpsStreamId)
            
            // アップストリーム情報をintdashサーバーと同期する。
            client.upstreamManager.sync(completion: { (error) in
                guard error == nil else {
                    completion(false)
                    self?.connectionError("Failed to request stream. \(error!.localizedDescription)")
                    return
                }
                print("Success to open stream.")
                // サーバーへデータを保存する場合は`IntdashDataFileManager`を利用してローカルストレージへデータの保存も行い再送アップロードを行える状態にします。
                if Config.INTDASH_IS_SAVE_TO_SERVER {
                    if sensorStreamId != nil {
                        do {
                            let fileManager = try IntdashDataFileManager(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(upstreamMeasId)/sensor")
                            try fileManager.setMeasurementId(id: upstreamMeasId)
                            self?.sensorDataFileManager = fileManager
                        } catch {
                            print("Failed to setup file manager. \(error)")
                        }
                    }
                    do {
                        let fileManager = try IntdashDataFileManager(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(upstreamMeasId)/gps")
                        try fileManager.setMeasurementId(id: upstreamMeasId)
                        self?.gpsDataFileManager = fileManager
                    } catch {
                        print("Failed to setup file manager. \(error)")
                    }
                }
                // ストリーム開始
                self?.sensorUpstreamId = sensorStreamId
                self?.gpsUpstreamId = gpsStreamId                
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
    
    public func connectionError(_ message: String) {
        guard !self.isShowAlertDialog else { return }
        self.isShowAlertDialog = true
        print(message)
        AlertDialogView.showAlert(viewController: self, title: "Connection Error", message: message) { [weak self] in
            self?.isShowAlertDialog = false
            self?.app.signOut()
        }
    }
    
    func sendFirstData(timestamp: TimeInterval) {
        self.baseTime = timestamp
        do {
            if let streamId = self.sensorUpstreamId {
                // データ送信前に保存を行います。
                try self.sensorDataFileManager?.setBaseTime(time: timestamp)
                /// ToDo
                /// チャンネルはストリームID毎に変更する事ができます。
                try self.sensorDataFileManager?.setStreamChannels(channels: Config.SENSOR_INTDASH_TARGET_CHANNEL)
                // 計測開始時間を送信します。
                try self.intdashClient?.upstreamManager.sendFirstData(timestamp, streamId: streamId, channelNum: Config.SENSOR_INTDASH_TARGET_CHANNEL)
                print("Success to send sensor first data. \(timestamp)")
            }
            if let streamId = self.gpsUpstreamId {
                // データ送信前の保存処理。
                try self.gpsDataFileManager?.setBaseTime(time: timestamp)
                /// ToDo
                /// チャンネルはストリームID毎に変更する事ができます。
                try self.gpsDataFileManager?.setStreamChannels(channels: Config.GPS_INTDASH_TARGET_CHANNEL)
                // 計測開始時間を送信します。
                try self.intdashClient?.upstreamManager.sendFirstData(timestamp, streamId: streamId, channelNum: Config.GPS_INTDASH_TARGET_CHANNEL)
                print("Success to send first data. \(timestamp)")
            }
            // NTPと同期し正しい計測開始時間を再送信します。
            self.syncNTP(baseTime: timestamp)
        } catch {
            print("Failed to send first data.\(error)")
            // Close Intdash Client
            self.closeIntdashClient()
        }
    }
    
    public func syncNTP(baseTime: TimeInterval) {
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
                    if let streamId = self.sensorUpstreamId {
                        // データ送信前の保存処理。
                        try self.sensorDataFileManager?.setBaseTime2(time: ntpTime)
                        // 生成した`IntdashData`を送信します。
                        try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: 0, streamId: streamId)
                    }
                    if let streamId = self.gpsUpstreamId {
                        // データ送信前の保存処理。
                        try self.gpsDataFileManager?.setBaseTime2(time: ntpTime)
                        // 生成した`IntdashData`を送信します。
                        try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: 0, streamId: streamId)
                    }
                    print("Successful send of synchronized base time. \(ntpTime)")
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
        
        // Send Last Data
        if let streamId = self.sensorUpstreamId {
            self.sensorUpstreamId = nil
            // `IntdashDataFileManager`に計測した期間を保存する事ができます。
            try? self.sensorDataFileManager?.setDuration(duration: duration)
            self.sensorDataFileManager = nil
            do {
                // 計測終了データを送信します。
                try client.upstreamManager.sendLastData(streamId: streamId)
            } catch {
                print("Failed to send sensor last data. \(error)")
            }
        }
        if let streamId = self.gpsUpstreamId {
            self.gpsUpstreamId = nil
            // `IntdashDataFileManager`に計測した期間を保存する事ができます。
            try? self.gpsDataFileManager?.setDuration(duration: duration)
            self.gpsDataFileManager = nil
            do {
                // 計測終了データを送信します。
                try client.upstreamManager.sendLastData(streamId: streamId)
            } catch {
                print("Failed to send gps last data. \(error)")
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
            if self.loadingDialog == nil {
                DispatchQueue.main.async { [weak self] in
                    self?.loadingDialog = LoadingAlertDialogView.init(addView: self!.app.window!, showMessageLabel: false)
                    self?.loadingDialog?.startAnimating()
                }
            }
        }
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
        print("didReceiveEndOfSection sectionId:\(sectionId), streamId:\(streamId), success:\(success), final:\(final), sentCount:\(sentCount) - IntdashClient.UpstreamManager")
        
        if final {
            generateSendLastDataCnt -= 1
            if generateSendLastDataCnt == 0 {
                // TODO: データの送信完了
                print("Completion of receiving final data. - IntdashClient.UpstreamManager")
                DispatchQueue.main.async { [weak self] in
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                }
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
