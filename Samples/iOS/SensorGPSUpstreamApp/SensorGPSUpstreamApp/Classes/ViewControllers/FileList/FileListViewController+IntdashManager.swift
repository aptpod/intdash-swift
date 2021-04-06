//
//  FileListViewController+IntdashManager.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
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
                        
                if measData.isSensor {
                    do {
                        print("Open for resend measurementID: \(measData.measId)")
                        let streamId = try client.upstreamManager.openForResend(measurementId: measData.measId, srcEdgeId: measData.edgeUUID, lastSectionId: nil)
                        print("Sensor UpstreamID: \(streamId)")
                        self?.upstreamIds.append(streamId)
                        self?.sensorUpstreamId = streamId
                    } catch {
                        print("Failed to open stream. \(error.localizedDescription)")
                        self?.closeIntdashClient(client: client)
                        completion(false)
                        return
                    }
                }
                
                if measData.isGPS {
                    do {
                        print("Open for resend measurementID: \(measData.measId)")
                        let streamId = try client.upstreamManager.openForResend(measurementId: measData.measId, srcEdgeId: measData.edgeUUID, lastSectionId: nil)
                        print("GPS UpstreamID: \(streamId)")
                        self?.upstreamIds.append(streamId)
                        self?.gpsUpstreamId = streamId
                    } catch {
                        print("Failed to open stream. \(error.localizedDescription)")
                        self?.closeIntdashClient(client: client)
                        completion(false)
                        return
                    }
                }
                
                guard self!.upstreamIds.count > 0 else {
                    print("StreamID not found")
                    self?.closeIntdashClient(client: client)
                    completion(false)
                    return
                }
                
                client.upstreamManager.sync(completion: { (error) in
                    guard error == nil else {
                        print("Failed to request stream. \(error!.localizedDescription)")
                        self?.closeIntdashClient(client: client)
                        completion(false)
                        return
                    }
                    print("Success to open stream.")
                    self?.intdashClient = client
                    self?.resendCheckCompletion = completion
                    self?.sensorSectionCnt = 0
                    self?.sensorSectionSize = 0
                    self?.gpsSectionCnt = 0
                    self?.gpsSectionSize = 0
                    self?.receivedFinalCnt = 0
                    DispatchQueue.global().async {
                        var index = 0
                        if let streamId = self?.sensorUpstreamId {
                            self?.sendData(client: client, measData: measData, streamId: streamId, fileIndex: index, fileSize: self!.upstreamIds.count, dataType: "sensor", completion: { (result) in
                                if !result { completion(false) }
                            })
                            index += 1
                        }
                        if let streamId = self?.gpsUpstreamId {
                            self?.sendData(client: client, measData: measData, streamId: streamId, fileIndex: index, fileSize: self!.upstreamIds.count, dataType: "gps", completion: { (result) in
                                if !result { completion(false) }
                            })
                            index += 1
                        }
                    }
                })
            }
        }
    }
    
    func sendData(client: IntdashClient, measData: MeasData, streamId: Int, fileIndex: Int, fileSize: Int, dataType: String, completion: (Bool)->()) {
        do {
            let fileManager = try IntdashDataFileManager.load(parentPath: "\(measData.measPath)/\(dataType)")
            let dataDuration = fileManager.getDataDuration()
            guard let channel = fileManager.streamChannels else {
                print("[\(dataType)] Stream channel not found.")
                completion(false)
                return
            }
            DispatchQueue.main.async {
                let progress = Int((Float(fileIndex) / Float(fileSize)) * 100)
                self.loadingDialog?.setMessage(message: "\(progress)% Uploading...")
            }
            // Send to First Data
            guard let baseTime = fileManager.baseTime, dataDuration > 0 else {
                self.receivedFinalCnt += 1
                completion(true)
                return
            }
            try client.upstreamManager.sendFirstData(baseTime, streamId: streamId, channelNum: channel)
            print("============> Send to [\(dataType)] FirstData: \(baseTime)")
            if let ntpTime = measData.ntpTime {
                try client.upstreamManager.sendUnit(IntdashData.DataBaseTime.init(type: .ntp, baseTime: ntpTime), elapsedTime: 0, streamId: streamId)
                print("Send to ntpTime: \(ntpTime)")
            }
            for i in 0..<dataDuration {
                if i % Config.INTDASH_UNITS_RESEND_TIME_INTERVAL == 0 {
                    // Wait thread loop
                    guard self.isReadyToSend(streamId: streamId) != nil else {
                        completion(false)
                        return
                    }
                    while(!(self.isReadyToSend(streamId: streamId) == true || !self.isRunning)) {
                        Thread.sleep(forTimeInterval: Config.INTDASH_WAIT_FOR_SEND_UNITS_INTERVAL)
                    }
                }
                print("[\(dataType)] Sending...[\(i)/\(dataDuration)]")
                let size = fileManager.getUnitSizePerSecond(elapsedTime: i)
                for j in 0..<size {
                    guard self.isRunning else {
                        completion(false)
                        return
                    }
                    autoreleasepool {
                        fileManager.read(elapsedTime: i, index: j, completion: { (error, units, elapsedTime) in
                            guard let units = units, let elapsedTime = elapsedTime else {
                                print("Failed to read [\(dataType)] units. \(error?.localizedDescription ?? "") [\(i)/\(dataDuration)][\(j)/\(size)]")
                                return
                            }
                            //print("[\(dataType)] Read[\(i)/\(dataDuration)][\(j)/\(size)] \(units.count) units, elapsed: \(elapsedTime)")
                            for unit in units {
                                do {
                                    try client.upstreamManager.sendUnit(unit, elapsedTime: elapsedTime, streamId: streamId)
                                } catch {
                                    print("Failed to send [\(dataType)] unit. \(error)")
                                }
                            }
                        })
                    }
                }
                DispatchQueue.main.async {
                    let progress = Int((Float(fileIndex) / Float(fileSize)) * 100) + Int(((Float(i) / Float(dataDuration)) / Float(fileSize)) * 100)
                    self.loadingDialog?.setMessage(message: "\(progress)% Uploading...")
                }
            }
            // Send to LastData
            try client.upstreamManager.sendLastData(streamId: streamId)
            print("Send to [\(dataType)] LastData <==================")
        } catch {
            print("[\(dataType)] intdash data file manager error. \(error)")
            self.closeIntdashClient(client: client)
            completion(false)
        }
    }
    
    func closeIntdashClient(client: IntdashClient) {
        self.intdashClient = nil
        DispatchQueue.global().async {
            let group = DispatchGroup()
            group.enter()
            client.upstreamManager.close(streamIds: self.upstreamIds, completion: { (error) in
                if let error = error {
                    print("Failed to close intdash upstream. \(error)")
                }
                client.upstreamManager.removeClosedUpstream()
                group.leave()
            })
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
        self.closeIntdashClient(client: client)
    }
    
    func intdashClient(_ client: IntdashClient, didRetryToRequestSpecs success: Bool) {}
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didGeneratedSesion sectionId: Int, sectionIndex: Int, streamId: Int, final: Bool, sentCount: Int, startOfElapsedTime: TimeInterval, endOfElapsedTime: TimeInterval) {
        print("didGeneratedSesion sectionId:\(sectionId), sectionIndex: \(sectionIndex), streamId:\(streamId), final:\(final), sentCount:\(sentCount), startOfElapsedTime:\(startOfElapsedTime), endOfElapsedTime:\(endOfElapsedTime) - IntdashClient.UpstreamManager")
        switch streamId {
        case self.sensorUpstreamId: self.sensorSectionSize += 1
        case self.gpsUpstreamId: self.gpsSectionSize += 1
        default: break
        }
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
        print("didReceiveEndOfSection sectionId:\(sectionId), streamId:\(streamId), success:\(success), final:\(final), sentCount:\(sentCount) - IntdashClient.UpstreamManager")
        if final {
            self.receivedFinalCnt += 1
            if self.receivedFinalCnt == self.upstreamIds.count {
                self.resendCheckCompletion?(true)                
            }
        }
        guard success else { return }
        switch streamId {
        case self.sensorUpstreamId: self.sensorSectionCnt += 1
        case self.gpsUpstreamId: self.gpsSectionCnt += 1
        default: break
        }
        
        if self.receivedFinalCnt == self.upstreamIds.count {
            DispatchQueue.global().async {
                if let client = self.intdashClient {
                    self.closeIntdashClient(client: client)
                }
            }
        }
    }
    
}
