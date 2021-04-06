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
    public func openIntdashClient(completion: @escaping (Bool)->()) {
        guard let session = IntdashAPIManager.shared.session else {
            print("Failed to get session.")
            completion(false)
            return
        }
               
        guard let edgeUUID = IntdashAPIManager.shared.singInEdgeUuid else {
            print("Failed to get edge uuid.")
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
        client.upstreamManager.addDelegate(delegate: self)
        client.connect { [weak self] (error) in
            guard error == nil else {
                print("Failed to connect intdash server. \(error!.localizedDescription)")
                completion(false)
                self?.connectionError()
                return
            }
            client.upstreamManager.requestMeasurementId(edgeUuid: edgeUUID, completion: { (measId, error) in
                guard error == nil, let upstreamMeasId = measId else {
                    print("Failed to get measurement ID.")
                    completion(false)
                    self?.connectionError()
                    return
                }
                print("MeasurementID: \(upstreamMeasId)")
                self?.upstreamMeasurementId = upstreamMeasId
                
                var sensorStreamId: Int? = nil
                if Config.SENSOR_IS_UPSTREAM {
                    do {
                        sensorStreamId = try client.upstreamManager.open(measurementId: upstreamMeasId, srcEdgeId: edgeUUID, dstEdgeIds: nil, store: Config.INTDASH_IS_SAVE_TO_SERVER, retryCount: 0, sectionUpdateInterval: nil)
                    } catch {
                        print("Failed to open stream. \(error.localizedDescription)")
                        completion(false)
                        self?.connectionError()
                        return
                    }
                    print("Sensor UpstreamID: \(sensorStreamId!)")
                    self?.upstreamIds.append(sensorStreamId!)
                }
                
                var gpsStreamId = 0
                do {
                    gpsStreamId = try client.upstreamManager.open(measurementId: upstreamMeasId, srcEdgeId: edgeUUID, dstEdgeIds: nil, store: Config.INTDASH_IS_SAVE_TO_SERVER, retryCount: 0, sectionUpdateInterval: nil)
                } catch {
                    print("Failed to open stream. \(error.localizedDescription)")
                    completion(false)
                    self?.connectionError()
                    return
                }
                print("GPS UpstreamID: \(gpsStreamId)")
                self?.upstreamIds.append(gpsStreamId)
                
                client.upstreamManager.sync(completion: { (error) in
                    guard error == nil else {
                        print("Failed to request stream. \(error!.localizedDescription)")
                        completion(false)
                        self?.connectionError()
                        return
                    }
                    print("Success to open stream.")
                    // Intdash Data File Manager
                    if Config.INTDASH_IS_SAVE_TO_SERVER {
                        if let streamId = sensorStreamId {
                            do {
                                let fileManager = try IntdashDataFileManager(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(upstreamMeasId)/sensor")
                                try fileManager.setMeasurementId(id: upstreamMeasId)
                                self?.sensorDataFileManager = fileManager
                                self?.sensorUpstreamId = streamId
                            } catch {
                                print("Failed to setup file manager. \(error)")
                            }
                        }
                        do {
                            let fileManager = try IntdashDataFileManager(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(upstreamMeasId)/gps")
                            try fileManager.setMeasurementId(id: upstreamMeasId)
                            self?.gpsDataFileManager = fileManager
                            self?.gpsUpstreamId = gpsStreamId
                        } catch {
                            print("Failed to setup file manager. \(error)")
                        }
                    }
                    self?.refreshNetworkTimeCnt = 0
                    self?.resetBaseTime()
                    completion(true)
                })
            })
        }
    }
    
    //MARK:- IntdashClientDelegate
    func intdashClientDidConnect(_ client: IntdashClient) {}
    
    func intdashClientDidDisconnect(_ client: IntdashClient) {
        self.stopStream()
    }
    
    func intdashClient(_ client: IntdashClient, didFailWithError error: Error?) {}
    
    func intdashClient(_ client: IntdashClient, didRetryToRequestSpecs success: Bool) {}
    
    public func connectionError() {
        guard !self.isShowAlertDialog else { return }
        self.isShowAlertDialog = true
        AlertDialogView.showAlert(viewController: self, title: "Connection Error", message: "Failed to connect to the server.") {
            self.isShowAlertDialog = false
        }
        self.stopStream()
    }
    
    func sendFirstData(timestamp: TimeInterval) {
        self.baseTime = timestamp
        do {
            if let streamId = self.sensorUpstreamId {
                /// ToDo
                /// チャンネルはストリームID毎に変更する事ができます。
                try self.intdashClient?.upstreamManager.sendFirstData(timestamp, streamId: streamId, channelNum: Config.SENSOR_INTDASH_TARGET_CHANNEL)
                try self.sensorDataFileManager?.setBaseTime(time: timestamp)
                try self.sensorDataFileManager?.setStreamChannels(channels: Config.SENSOR_INTDASH_TARGET_CHANNEL)
                print("Success to send sensor first data. \(timestamp)")
            }
            if let streamId = self.gpsUpstreamId {
                /// ToDo
                /// チャンネルはストリームID毎に変更する事ができます
                try self.intdashClient?.upstreamManager.sendFirstData(timestamp, streamId: streamId, channelNum: Config.GPS_INTDASH_TARGET_CHANNEL)
                try self.gpsDataFileManager?.setBaseTime(time: timestamp)
                try self.gpsDataFileManager?.setStreamChannels(channels: Config.GPS_INTDASH_TARGET_CHANNEL)
                print("Success to send first data. \(timestamp)")
            }
            // Sync NTP.
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
                    let baseTime = IntdashData.DataBaseTime.init(type: .ntp, baseTime: ntpTime)
                    if let streamId = self.sensorUpstreamId {
                        try self.intdashClient?.upstreamManager.sendUnit(baseTime, elapsedTime: 0, streamId: streamId)
                        try self.sensorDataFileManager?.setBaseTime2(time: ntpTime)
                    }
                    if let streamId = self.gpsUpstreamId {
                        try self.intdashClient?.upstreamManager.sendUnit(baseTime, elapsedTime: 0, streamId: streamId)
                        try self.gpsDataFileManager?.setBaseTime2(time: ntpTime)
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
    
    public func closeIntdashClient() {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        print("closeIntdashClient() >>>")
        self.intdashClient = nil
        // Duration
        let duration = MySystemClock.shared.rtcDate.timeIntervalSince1970-self.baseTime
        
        // Send Last Data
        if let streamId = self.sensorUpstreamId {
            self.sensorUpstreamId = nil
            try? self.sensorDataFileManager?.setDuration(duration: duration)
            self.sensorDataFileManager = nil
            do {
                try client.upstreamManager.sendLastData(streamId: streamId)
            } catch {
                print("Failed to send sensor last data. \(error)")
            }
        }
        if let streamId = self.gpsUpstreamId {
            self.gpsUpstreamId = nil
            try? self.gpsDataFileManager?.setDuration(duration: duration)
            self.gpsDataFileManager = nil
            do {
                try client.upstreamManager.sendLastData(streamId: streamId)
            } catch {
                print("Failed to send gps last data. \(error)")
            }
        }
        
        DispatchQueue.global().async {
            let group = DispatchGroup()
            let streamIds = self.upstreamIds
            self.upstreamIds.removeAll()
            if streamIds.count > 0 {
                group.enter()
                client.upstreamManager.close(streamIds: streamIds) { (error) in
                    if error != nil {
                        print("Failed to close intdash upstream. \(error!)")
                    }
                    client.upstreamManager.removeClosedUpstream()
                    group.leave()
                }
            }
            
            group.notify(queue: .global()) {
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
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didGeneratedSesion sectionId: Int, sectionIndex: Int, streamId: Int, final: Bool, sentCount: Int, startOfElapsedTime: TimeInterval, endOfElapsedTime: TimeInterval) {
        print("didGeneratedSesion sectionId:\(sectionId), sectionIndex: \(sectionIndex), streamId:\(streamId), final:\(final), sentCount:\(sentCount), startOfElapsedTime:\(startOfElapsedTime), endOfElapsedTime:\(endOfElapsedTime) - IntdashClient.UpstreamManager")
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
        print("didReceiveEndOfSection sectionId:\(sectionId), streamId:\(streamId), success:\(success), final:\(final), sentCount:\(sentCount) - IntdashClient.UpstreamManager")
        
        // Badnetwork Management
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
