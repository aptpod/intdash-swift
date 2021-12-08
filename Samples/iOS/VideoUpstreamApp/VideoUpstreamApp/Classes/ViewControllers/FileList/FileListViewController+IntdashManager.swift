//
//  FileListViewController+IntdashManager.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import Intdash

extension FileListViewController: IntdashClientDelegate, IntdashClientUpstreamManagerDelegate {
    
    func uploadData(measData: MeasData, completion: @escaping (Bool)->()) {
        guard let session = IntdashAPIManager.shared.session else {
            print("Failed to get session.")
            completion(false)
            return
        }
        
        // IntdashClient
        let client = IntdashClient()
        client.session = session
        client.addDelegate(self)
        client.upstreamManager.addDelegate(delegate: self)
        
        // サーバーに計測が存在しているか確認してから再送を行います。
        client.measurements.list(uuid: measData.measId) { (response, error) in
            guard response?.items.first?.uuid == measData.measId else {
                print("The specified measurement does not exist on the server.")
                completion(false)
                return
            }
            
            client.connect { [weak self] (error) in
                guard error == nil else {
                    print("Failed to connect intdash server. \(error!.localizedDescription)")
                    completion(false)
                    return
                }
                
                var streamId = 0
                do {
                    print("Open for resend measurementID: \(measData.measId)")
                    streamId = try client.upstreamManager.openForResend(measurementId: measData.measId, srcEdgeId: measData.edgeUUID, lastSectionId: nil)
                } catch {
                    print("Failed to open stream. \(error.localizedDescription)")
                    self?.closeIntdashClient(client: client, streamId: nil)
                    completion(false)
                    return
                }
                print("UpstreamID: \(streamId)")
                
                client.upstreamManager.sync(completion: { (error) in
                    guard error == nil else {
                        print("Failed to request stream. \(error!.localizedDescription)")
                        self?.closeIntdashClient(client: client, streamId: streamId)
                        completion(false)
                        return
                    }
                    print("Success to open stream.")
                    self?.intdashClient = client
                    self?.upstreamId = streamId
                    self?.resendCheckCompletion = completion
                    self?.sectionCnt = 0
                    self?.sectionSize = 0
                    DispatchQueue.global().async {
                        do {
                            // `IntdashDataFileManager`を利用して保存されたデータを読み出します。
                            let fileManager = try IntdashDataFileManager.load(parentPath: measData.measPath)
                            // 保存されているデータを参照する為に実際に保存されているデータの期間を取得します。
                            let dataDuration = fileManager.getDataDuration()
                            DispatchQueue.main.async {
                                self?.loadingDialog?.setMessage(message: "0% Uploading...")
                            }
                            // Send to First Data
                            guard let baseTime = fileManager.baseTime, dataDuration > 0 else {
                                completion(true)
                                return
                            }
                            // 計測開始時間を送信します。
                            try client.upstreamManager.sendFirstData(baseTime, streamId: streamId, channelNum: Config.INTDASH_TARGET_CHANNEL)
                            print("============> Sent to FirstData: \(baseTime)")
                            if let ntpTime = measData.ntpTime {
                                // NTPと同期した計測開始時間が存在すれば存在すれば送信します。
                                try client.upstreamManager.sendUnit(IntdashData.DataBaseTime.init(type: .ntp, baseTime: ntpTime), elapsedTime: 0, streamId: streamId)
                                print("Send to ntpTime: \(ntpTime)")
                            }
                            for i in 0..<dataDuration {
                                if i % Config.INTDASH_UNITS_RESEND_TIME_INTERVAL == 0 {
                                    // 送信中のセクションと反映済みセクションが同じタイミングのみ再送を有効とします。
                                    while(!(self!.isReadySendUnitReceivedAck || !self!.isRunning)) {
                                        Thread.sleep(forTimeInterval: Config.INTDASH_WAIT_FOR_SEND_UNITS_INTERVAL)
                                    }
                                }
                                print("Sending...[\(i)/\(dataDuration)]")
                                // 経過時間(秒)毎のデータ数を取得します。
                                let size = fileManager.getUnitSizePerSecond(elapsedTime: i)
                                for j in 0..<size {
                                    guard self!.isRunning else {
                                        completion(false)
                                        return
                                    }
                                    autoreleasepool {
                                        // 指定した経過時間、indexの`IntdashData`を読み込みます。
                                        fileManager.read(elapsedTime: i, index: j, completion: { (error, units, elapsedTime) in
                                            guard let units = units, let elapsedTime = elapsedTime else {
                                                print("Failed to read frame. \(error?.localizedDescription ?? "") [\(i)/\(dataDuration)][\(j)/\(size)]")
                                                return
                                            }
                                            print("Read[\(i)/\(dataDuration)][\(j)/\(size)] \(units.count) units, elapsed: \(elapsedTime)")
                                            for unit in units {
                                                do {
                                                    // 読み込んだ`IntdashData`を再送信します。
                                                    try client.upstreamManager.sendUnit(unit, elapsedTime: elapsedTime, streamId: streamId)
                                                } catch {
                                                    print("Failed to send unit. \(error)")
                                                }
                                            }
                                        })
                                    }
                                }
                                DispatchQueue.main.async {
                                    let progress = Int(((Float(i) / Float(dataDuration))) * 100)
                                    self?.loadingDialog?.setMessage(message: "\(progress)% Uploading...")
                                }
                            }
                            // 計測終了データを送信します。
                            try client.upstreamManager.sendLastData(streamId: streamId)
                            print("Send to LastData <==================")
                        } catch {
                            print("Unit data file manager error. \(error)")
                            self?.closeIntdashClient(client: client, streamId: streamId)
                            completion(false)
                        }
                    }
                })
            }
        }
    }
    
    func closeIntdashClient(client: IntdashClient, streamId: Int?) {
        self.intdashClient = nil
        self.upstreamId = nil
        DispatchQueue.global().async {
            let group = DispatchGroup()
            if let streamId = streamId {
                group.enter()
                client.upstreamManager.close(streamIds: [streamId], completion: { (error) in
                    if let error = error {
                        print("Failed to close intdash upstream. \(error)")
                    }
                    client.upstreamManager.removeClosedUpstream()
                    group.leave()
                })
            }
            
            group.notify(queue: .global(), execute: {
                client.disconnect(completion: { (error) in
                    if let error = error {
                        print("Failed to disconnect intdash client. \(error)")
                    } else {
                        print("Success to disconnect intdash client.")
                    }
                    client.removeDelegate(self)
                })
            })
        }
    }
    
    func intdashClientDidConnect(_ client: IntdashClient) {
        print("intdashClientDidConnect - IntdashClient")
    }
    
    func intdashClientDidDisconnect(_ client: IntdashClient) {
        print("intdashClientDidDisconnect - IntdashClient")
    }
    
    func intdashClient(_ client: IntdashClient, didFailWithError error: Error?) {
        print("didFailWithError \(error?.localizedDescription ?? "") - IntdashClient")
        self.closeIntdashClient(client: client, streamId: self.upstreamId)
    }
    
    func intdashClient(_ client: IntdashClient, didRetryToRequestSpecs success: Bool) {}
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didGeneratedSesion sectionId: Int, sectionIndex: Int, streamId: Int, final: Bool, sentCount: Int, startOfElapsedTime: TimeInterval, endOfElapsedTime: TimeInterval) {
        print("didGeneratedSesion sectionId:\(sectionId), sectionIndex: \(sectionIndex), streamId:\(streamId), final:\(final), sentCount:\(sentCount), startOfElapsedTime:\(startOfElapsedTime), endOfElapsedTime:\(endOfElapsedTime) - IntdashClient.UpstreamManager")
        self.sectionSize += 1
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
        print("didReceiveEndOfSection sectionId:\(sectionId), streamId:\(streamId), success:\(success), final:\(final), sentCount:\(sentCount) - IntdashClient.UpstreamManager")
        if final { self.resendCheckCompletion?(true) }
        guard success else { return }
        self.sectionCnt += 1
        
        // 最終データが正しく反映された場合はストリームを閉じアップロード処理を終了します。
        if final {
            DispatchQueue.global().async {
                if let client = self.intdashClient {
                    self.closeIntdashClient(client: client, streamId: streamId)
                }
            }
        }
    }
    
}
