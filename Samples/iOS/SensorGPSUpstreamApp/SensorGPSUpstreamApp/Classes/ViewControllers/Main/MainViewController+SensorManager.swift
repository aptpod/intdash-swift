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
        // 計測開始時間が未送信であれば送信します。
        if self.baseTime == -1 {
            self.sendFirstData(timestamp: rtcTime)
        }
        if self.motionBaseTime == -1 {
            self.motionBaseTime = rtcTime
            self.motionSampleBaseTime = motion.timestamp
        }
        self.clockLock.unlock()
        
        // 計測開始時間から経過時間を算出します。
        let elapsedTime = ((motion.timestamp - self.motionSampleBaseTime) + self.motionBaseTime) - self.baseTime
        guard elapsedTime >= 0 else {
            print("Elapsed time error. \(elapsedTime)")
            return
        }
        DispatchQueue.global().async {
            do {
                var units = [IntdashData]()
                
                if Config.SENSOR_IS_ENABLED_ACCELERATION {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorAcceleration(ax: self.toMs2(motion.userAcceleration.x), ay: self.toMs2(motion.userAcceleration.y), az: self.toMs2(motion.userAcceleration.z))
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // 同時刻のデータはひとまとめにして送信可能です。
                    units.append(data)
                }
                if Config.SENSOR_IS_ENABLED_GRAVITY_ACCELERATION {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorGravity(gx: self.toMs2(motion.gravity.x), gy: self.toMs2(motion.gravity.y), gz: self.toMs2(motion.gravity.z))
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // 同時刻のデータはひとまとめにして送信可能です。
                    units.append(data)
                }
                if Config.SENSOR_IS_ENABLED_ROTATION_RATE {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorRotationRate(rra: self.toDegrees(motion.rotationRate.z), rrb: self.toDegrees(motion.rotationRate.x), rrg: self.toDegrees(motion.rotationRate.y))
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // 同時刻のデータはひとまとめにして送信可能です。
                    units.append(data)
                }
                if Config.SENSOR_IS_ENABLED_ORIENTATION_ANGLE {
                    // 送信する`IntdashData`を生成します。
                    let sensor = GeneralSensorOrientationAngle(oaa: self.toDegrees(motion.attitude.yaw), oab: self.toDegrees(motion.attitude.pitch), oag: self.toDegrees(motion.attitude.roll))
                    // `GeneralSensor***`は`IntdashData`に変換が可能。
                    let data = sensor.toData()
                    // 同時刻のデータはひとまとめにして送信可能です。
                    units.append(data)
                }
                if !units.isEmpty {
                    // データ送信前の保存処理。
                    if let fileManager = self.sensorDataFileManager {
                        _ = try fileManager.write(units: units, elapsedTime: elapsedTime)
                    }
                    // 生成した`IntdashData`を送信します。
                    try self.intdashClient?.upstreamManager.sendUnits(units, elapsedTime: elapsedTime, streamId: streamId)
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
