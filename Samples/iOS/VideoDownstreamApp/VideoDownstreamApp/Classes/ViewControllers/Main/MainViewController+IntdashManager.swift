//
//  MainViewController+IntdashManager.swift
//  VideoDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import Intdash

extension MainViewController: IntdashClientDelegate, IntdashClientDownstreamManagerDelegate {
    
    //MARK:- IntdashClient
    public func openIntdashClient(completion: @escaping (Bool)->()) {
        guard let session = IntdashAPIManager.shared.session else {
            print("Failed to get session.")
            completion(false)
            return
        }
               
        guard let edgeUUID = self.app.targetEdge?.uuid else {
            print("Failed to get edge uuid.")
            completion(false)
            return
        }
        
        let channel = self.app.targetChannel
        
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
        client.downstreamManager.addDelegate(delegate: self)
        client.connect{ [weak self] (error) in
            guard error == nil else {
                print("Failed to connect intdash server. \(error!.localizedDescription)")
                completion(false)
                self?.connectionError()
                return
            }
            
            var streamId = 0
            do {
                streamId = try client.downstreamManager.open(srcEdgeId: edgeUUID)
            } catch {
                print("Failed to open stream. \(error.localizedDescription)")
                completion(false)
                self?.connectionError()
                return
            }
            print("DownstreamID: \(streamId)")
            self?.downstreamId = streamId
            self?.downstreamIds.append(streamId)
            
            // Make Downstream Filters
            let filters = self?.makeDownstreamFilters(streamId: streamId, channel: channel)

            client.downstreamManager.sync(completion: { [weak self] (error) in
                guard error == nil else {
                    print("Failed to request stream.")
                    completion(false)
                    self?.connectionError()
                    return
                }
                print("Success to open stream.")
                completion(true)
            }, filters: filters)
        }
    }
    
    func makeDownstreamFilters(streamId: Int, channel: Int) -> IntdashClient.DownstreamManager.RequestFilters {
        let filters = IntdashClient.DownstreamManager.RequestFilters()
        filters.append(streamId: streamId, channelNum: channel, dataType: .jpeg, id: nil)
        /// ToDo
        //filters.append(streamId: streamId, channelNum: channel, dataType: .h264, id: "nil")
        //filters.append(streamId: streamId, channelNum: channel, dataType: .h265, id: "nil")
        //filters.append(streamId: streamId, channelNum: channel, dataType: .pcm, id: "nil")
        //filters.append(streamId: streamId, channelNum: channel, dataType: .aac, id: "nil")
        return filters
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
    
    public func closeIntdashClient() {
        // Exclusion Control
        self.webSocketLock.lock()
        defer { self.webSocketLock.unlock() }
        
        guard let client = self.intdashClient else { return }
        print("closeIntdashClient() >>>")
        self.intdashClient = nil

        DispatchQueue.global().async {
            self.downstreamId = -1

            let group = DispatchGroup()
            let streamIds = self.downstreamIds
            self.downstreamIds.removeAll()
            if streamIds.count > 0 {
                group.enter()
                client.downstreamManager.close(streamIds: streamIds) { (error) in
                    if error != nil {
                        print("Failed to close intdash downstream. \(error!)")
                    }
                    client.downstreamManager.removeClosedDownstream()
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
    
    func downstreamManagerDidParseDataPoints(_ manager: IntdashClient.DownstreamManager, streamId: Int, dataPoints: [RealtimeDataPoint]) {
        dataPoints.forEach { (dataPoint) in
            guard dataPoint.dataModel.dataType != .baseTime else {
                print("BaseTime recieved. streamId:\(streamId), id:\(dataPoint.dataId), time:\(dataPoint.time.rfc3339String)")
                if (dataPoint.dataModel as? IntdashData.DataBaseTime)?.type == .api {
                    NSLog("Measurement started BaseTime recieved.")
                }
                return
            }
            guard let data = dataPoint.data as? Data else { return }
            print("Binary data received. streamId:\(streamId), dataType:\(dataPoint.dataType), dataId:\(dataPoint.dataId), time:\(dataPoint.time.rfc3339String), size:\(data.count)")
            switch dataPoint.dataModel.dataType {
            case .jpeg:
                DispatchQueue.global().async {
                    self.decodeJpeg(jpeg: data, timestamp: dataPoint.time.timeIntervalSince1970)
                }
            case .h264:
                /// ToDo
                /// `IntdashMediaSDK` を利用するとデコード可能です。
                break
            case .h265:
                /// ToDo
                /// `IntdashMediaSDK` を利用するとデコード可能です。
                break
            case .pcm:
                /// ToDo
                /// `IntdashMediaSDK` を利用すると再生が可能です。
                break
            case .aac:
                /// ToDo
                /// `IntdashMediaSDK` を利用するとデコード及び再生が可能です。
                break
            default: break
            }
        }
    }
}
