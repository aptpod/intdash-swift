//
//  MainViewController+GPSManager.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/18.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import Intdash

extension MainViewController: CLLocationManagerDelegate {
    
    func setupGPSManager() {
        DispatchQueue.main.async {
            self.locationManager.desiredAccuracy = Config.GPS_LOCATION_ACCURACY
            self.locationManager.delegate = self
            if CLLocationManager.authorizationStatus() == .notDetermined || CLLocationManager.authorizationStatus() == .denied {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                self.locationManager.startUpdatingLocation()
                self.locationManager.startUpdatingHeading()
                self.updateGpsHeadingOrientaiton()
            }            
        }
    }
    
    func disposeGPSManager() {
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopUpdatingHeading()
        self.locationManager.delegate = self
    }
    
    func updateGpsHeadingOrientaiton() {
        switch self.view.interfaceOrientation {
        case .landscapeLeft:
            self.locationManager.headingOrientation = .landscapeRight
        case .landscapeRight:
            self.locationManager.headingOrientation = .landscapeLeft
        case .portrait:
            self.locationManager.headingOrientation = .portrait
        case .portraitUpsideDown:
            self.locationManager.headingOrientation = .portraitUpsideDown
        default: break
        }
    }
    
    //MARK:- CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("didChangeAuthorization \(status.rawValue) - CLLocationManager")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
            self.locationManager = manager
            self.updateGpsHeadingOrientaiton()
            break
        default: break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let rtcTime = MySystemClock.shared.rtcDate.timeIntervalSince1970
        if let location = locations.last {
            print("locationManager didUpdateLocations sampleTime: \(location.timestamp.timeIntervalSince1970) latitude: \(location.coordinate.latitude), longitude: \(location.coordinate.longitude) - CLLocationManager")
            self.sendLocation(location: location, rtcTime: rtcTime)
        }
    }
    
    func sendLocation(location: CLLocation, rtcTime: TimeInterval) {
        guard let streamId = self.gpsUpstreamId else { return }
        
        self.clockLock.lock()
        // 計測開始時間が未送信であれば送信します。
        if self.baseTime == -1 {
            self.sendFirstData(timestamp: rtcTime)
        }
        if self.locationBaseTime == -1 {
            self.locationBaseTime = rtcTime
            self.locationSampleBaseTime = location.timestamp.timeIntervalSince1970
        }
        self.clockLock.unlock()
        
        // 計測開始時間から経過時間を算出します。
        let elapsedTime = ((location.timestamp.timeIntervalSince1970 - self.locationSampleBaseTime) + self.locationBaseTime) - self.baseTime
        guard elapsedTime >= 0 else {
            print("Elapsed time error. \(elapsedTime)")
            return
        }
        DispatchQueue.global().async {
            do {
                if !Config.GPS_IS_PRIMITIVE_DATA {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorGeoLocationCoordinate(lat: Float(location.coordinate.latitude), lng: Float(location.coordinate.longitude))
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // データ送信前の保存処理。
                    if let fileManager = self.gpsDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                } else {
                    // 送信する`IntdashData`を生成します。
                    let lat = try IntdashData.DataFloat(id: Config.GPS_PRIMITIVE_DATA_LATITUDE_ID, data: location.coordinate.latitude)
                    let lng = try IntdashData.DataFloat(id: Config.GPS_PRIMITIVE_DATA_LONGITUDE_ID, data: location.coordinate.longitude)
                    // データ送信前の保存処理。
                    if let fileManager = self.gpsDataFileManager {
                        _ = try fileManager.write(units: [lat, lng], elapsedTime: elapsedTime)
                    }
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnit(lat, elapsedTime: elapsedTime, streamId: streamId)
                    try self.intdashClient?.upstreamManager.sendUnit(lng, elapsedTime: elapsedTime, streamId: streamId)
                }
            } catch {
                print("Failed to send location coordinate. \(error)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let rtcTime = MySystemClock.shared.rtcDate.timeIntervalSince1970
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading: Float = Float(newHeading.trueHeading)
        print("locationManager didUpdateHeading sampleTime: \(newHeading.timestamp.timeIntervalSince1970) heading: \(heading) - CLLocationManager")
        self.sendHeading(heading: heading, rtcTime: rtcTime, sampleTime: newHeading.timestamp.timeIntervalSince1970)
    }
    
    func sendHeading(heading: Float, rtcTime: TimeInterval, sampleTime: TimeInterval) {
        guard let streamId = self.gpsUpstreamId else { return }
        
        self.clockLock.lock()
        // 計測開始時間が未送信であれば送信します。
        if self.baseTime == -1 {
            self.sendFirstData(timestamp: rtcTime)
        }
        if self.headBaseTime == -1 {
            self.headBaseTime = rtcTime
            self.headSampleBaseTime = sampleTime
        }
        self.clockLock.unlock()
        
        // 計測開始時間から経過時間を算出します。
        let elapsedTime = ((sampleTime - self.headSampleBaseTime) + self.headBaseTime) - self.baseTime
        guard elapsedTime >= 0 else {
            print("Elapsed time error. \(elapsedTime)")
            return
        }
        DispatchQueue.global().async {
            do {
                if !Config.GPS_IS_PRIMITIVE_DATA {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorGeoLocationHeading(head: heading)
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // データ送信前の保存処理。
                    if let fileManager = self.gpsDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                } else {
                    // 送信する`IntdashData`を生成します。
                    let data = try IntdashData.DataFloat(id: Config.GPS_PRIMITIVE_DATA_HEAD_ID, data: Float64(heading))
                    // データ送信前の保存処理。
                    if let fileManager = self.gpsDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                }
            } catch {
                print("Failed to send location heading. \(error)")
            }
        }
    }
}
