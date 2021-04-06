//
//  MainViewController+SensorManager.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/18.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreMotion
import Intdash

extension MainViewController {
    
    func setupSensorManager() {
        DispatchQueue.main.async {
            self.motionManager.deviceMotionUpdateInterval = 1 / Double(Config.SENSOR_SAMPLING_RATE)
            self.motionManager.startDeviceMotionUpdates(using: Config.SENSOR_USING_TYPE, to: OperationQueue.current!) { [weak self] (motion, error) in
                let rtcTime = MySystemClock.shared.rtcDate.timeIntervalSince1970
                guard let motion = motion else { return }
                //print("motionManager didUpdateMotionValues sampleTime: \(motion.timestamp)")
                self?.outputSensors(motion: motion)
                self?.sendSensors(motion: motion, rtcTime: rtcTime)
            }
        }
    }
    
    func outputSensors(motion: CMDeviceMotion) {
        DispatchQueue.global().async {
            let sensorValues = NSMutableString("■Sensors\n")
            if Config.SENSOR_IS_ENABLED_ACCELERATION {
                sensorValues.append("Acceleration:\n")
                sensorValues.append("x: \(self.toMs2(motion.userAcceleration.x))\n")
                sensorValues.append("y: \(self.toMs2(motion.userAcceleration.y))\n")
                sensorValues.append("z: \(self.toMs2(motion.userAcceleration.z))\n")
            }
            if Config.SENSOR_IS_ENABLED_GRAVITY_ACCELERATION {
                sensorValues.append("Gravity:\n")
                sensorValues.append("x: \(self.toMs2(motion.gravity.x))\n")
                sensorValues.append("y: \(self.toMs2(motion.gravity.y))\n")
                sensorValues.append("z: \(self.toMs2(motion.gravity.z))\n")
            }
            if Config.SENSOR_IS_ENABLED_ROTATION_RATE {
                sensorValues.append("RotationRate:\n")
                sensorValues.append("x: \(self.toDegrees(motion.rotationRate.x))\n")
                sensorValues.append("y: \(self.toDegrees(motion.rotationRate.y))\n")
                sensorValues.append("z: \(self.toDegrees(motion.rotationRate.z))\n")
            }
            if Config.SENSOR_IS_ENABLED_ORIENTATION_ANGLE {
                sensorValues.append("OrientationAngle:\n")
                sensorValues.append("roll: \(self.toDegrees(motion.attitude.roll))\n")
                sensorValues.append("pitch: \(self.toDegrees(motion.attitude.pitch))\n")
                sensorValues.append("yaw: \(self.toDegrees(motion.attitude.yaw))\n")                
            }
            DispatchQueue.main.async {
                self.sensorValueLabel.text = String(sensorValues)
            }
        }
    }
    
    func disposeSensorManager() {
        if self.motionManager.isDeviceMotionActive {
            self.motionManager.stopDeviceMotionUpdates()
        }
    }
    
    func sendSensors(motion: CMDeviceMotion, rtcTime: TimeInterval) {
        guard let streamId = self.sensorUpstreamId else { return }
        
        self.clockLock.lock()
        if self.baseTime == -1 {
            self.sendFirstData(timestamp: rtcTime)
        }
        if self.motionBaseTime == -1 {
            self.motionBaseTime = rtcTime
            self.motionSampleBaseTime = motion.timestamp
        }
        self.clockLock.unlock()
        
        let elapsedTime = ((motion.timestamp - self.motionSampleBaseTime) + self.motionBaseTime) - self.baseTime
        guard elapsedTime >= 0 else {
            print("Elapsed time error. \(elapsedTime)")
            return
        }
        DispatchQueue.global().async {
            do {
                if Config.SENSOR_IS_ENABLED_ACCELERATION {
                    let sensor = GeneralSensorAcceleration(ax: self.toMs2(motion.userAcceleration.x), ay: self.toMs2(motion.userAcceleration.y), az: self.toMs2(motion.userAcceleration.z))
                    let data = sensor.toData()
                    if let fileManager = self.sensorDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                }
                if Config.SENSOR_IS_ENABLED_GRAVITY_ACCELERATION {
                    let sensor = GeneralSensorGravity(gx: self.toMs2(motion.gravity.x), gy: self.toMs2(motion.gravity.y), gz: self.toMs2(motion.gravity.z))
                    let data = sensor.toData()
                    if let fileManager = self.sensorDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                }
                if Config.SENSOR_IS_ENABLED_ROTATION_RATE {
                    let sensor = GeneralSensorRotationRate(rra: self.toDegrees(motion.rotationRate.z), rrb: self.toDegrees(motion.rotationRate.x), rrg: self.toDegrees(motion.rotationRate.y))
                    let data = sensor.toData()
                    if let fileManager = self.sensorDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                }
                if Config.SENSOR_IS_ENABLED_ORIENTATION_ANGLE {
                    let sensor = GeneralSensorOrientationAngle(oaa: self.toDegrees(motion.attitude.yaw), oab: self.toDegrees(motion.attitude.pitch), oag: self.toDegrees(motion.attitude.roll))
                    let data = sensor.toData()
                    if let fileManager = self.sensorDataFileManager {
                        _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                    }
                    try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
                }
            } catch {
                print("Failed to send location heading. \(error)")
            }
        }
    }
    
    // G -> m/s2
    func toMs2(_ g: Double) -> Float {
        let ret = g * 9.80665
        return Float(ret)
    }

    // radians/second -> degrees/second
    func toDegrees(_ radians: Double) -> Float {
        let ret = 180 / Double.pi * radians
        return Float(ret)
    }
}
