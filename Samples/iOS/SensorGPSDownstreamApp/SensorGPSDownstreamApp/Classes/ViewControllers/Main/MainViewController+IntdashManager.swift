//
//  MainViewController+IntdashManager.swift
//  SensorGPSDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/23.
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
        client.connect { [weak self] (error) in
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
            let filters = self?.makeDownstreamFilters(streamId: streamId)

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
    
    func makeDownstreamFilters(streamId: Int) -> IntdashClient.DownstreamManager.RequestFilters {
        let filters = IntdashClient.DownstreamManager.RequestFilters()
        filters.append(streamId: streamId, channelNum: self.app.targetSensorChannel, dataType: .generalSensor, id: nil)
        filters.append(streamId: streamId, channelNum: self.app.targetGPSChannel, dataType: .float, id: Config.GPS_PRIMITIVE_DATA_LATITUDE_ID)
        filters.append(streamId: streamId, channelNum: self.app.targetGPSChannel, dataType: .float, id: Config.GPS_PRIMITIVE_DATA_LONGITUDE_ID)
        filters.append(streamId: streamId, channelNum: self.app.targetGPSChannel, dataType: .float, id: Config.GPS_PRIMITIVE_DATA_HEAD_ID)
        // ToDo
        //filters.append(streamId: streamId, channelNum: self.app.targetGPSChannel, dataType: .nmea, id: "RMC")
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
            self.downstreamId = nil

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
            print("Data received. streamId:\(streamId), type:\(dataPoint.dataType), dataId:\(dataPoint.dataId), time:\(dataPoint.time.rfc3339String)")
            switch dataPoint.dataModel.dataType {
            case .generalSensor:
                guard let dataGeneralSensor = dataPoint.dataModel as? IntdashData.DataGeneralSensor else { return }
                do {
                    let sensor = try GeneralSensorUtils.sensorFromDataGeneralSensor(dataGeneralSensor, byteOrder: .littleEndian)
                    self.sensorDataLock.lock()
                    if let sensor = sensor as? GeneralSensorGeoLocationCoordinate {
                        self.setUserLocation(latitude: Double(sensor.lat), longitude: Double(sensor.lng))
                    } else if let sensor = sensor as? GeneralSensorGeoLocationHeading {
                        self.setUserHead(head: Double(sensor.head))
                    } else if let _ = sensor as? GeneralSensorGeoLocationSpeed {
                        // ToDo
                    } else if let sensor = sensor as? GeneralSensorAcceleration {
                        self.sensorAcceleration = sensor
                    } else if let _ = sensor as? GeneralSensorAccelerationIncludingGravity {
                        // ToDo
                    } else if let sensor = sensor as? GeneralSensorGravity {
                        self.sensorGravity = sensor
                    } else if let sensor = sensor as? GeneralSensorRotationRate {
                        self.sensorRotationRate = sensor
                    } else if let sensor = sensor as? GeneralSensorOrientationAngle {
                        self.sensorOrientationAngle = sensor
                    } else if let _ = sensor as? GeneralSensorGeoLocationAltitude {
                        // ToDo
                    } else if let _ = sensor as? GeneralSensorGeoLocationAccuracy {
                        // ToDo
                    }
                    self.sensorDataLock.unlock()
                } catch {
                    print("Failed to convert sensor data. \(error.localizedDescription)")
                }
            case .nmea:
                guard let dataNMEA = dataPoint.dataModel as? IntdashData.DataNMEA else { return }
                do {
                    let nmea = try NMEAUtils.nmeaFromDataNMEA(dataNMEA)
                    if let _ = nmea as? NMEARMC {
                        // ToDo
                    }
                } catch {
                    print("Failed to convert nmea data. \(error)")
                }
            default: break
            }
        }
    }
}
