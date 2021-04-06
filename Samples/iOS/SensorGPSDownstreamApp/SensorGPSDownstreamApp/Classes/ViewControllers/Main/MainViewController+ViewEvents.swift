//
//  MainViewController+ViewEvents.swift
//  SensorGPSDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/23.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func setupViewEvents() {
        self.streamControlBtn.addTarget(self, action: #selector(streamControlBtnPushed(_:)), for: .touchUpInside)
        self.currentTimeFormat = DateFormatter()
        self.currentTimeFormat.dateFormat = Config.CURRENT_TIME_FORMAT_STRING
    }
    
    @IBAction func streamControlBtnPushed(_ sender: Any) {
        print("streamControlBtnPushed")
        self.startStream()
    }
    
    func updateStreamControlBtn() {
        DispatchQueue.main.async {
            if self.intdashClient != nil {
                self.streamControlBtn.setTitle("STOP DOWNSTREAM", for: .normal)
                self.streamControlBtn.setTitleColor(Config.BUTTON_ACTIVE_TEXT_COLOR, for: .normal)
                self.startCurrentTimeCheckTimer()
            } else {
                self.streamControlBtn.setTitle("START DOWNSTREAM", for: .normal)
                self.streamControlBtn.setTitleColor(Config.BUTTON_DEACTIVE_TEXT_COLOR, for: .normal)
                self.stopCurrentTimeCheckTimer()
            }
        }
    }
    
    func startCurrentTimeCheckTimer() {
        guard self.displayLink == nil else { return }
        self.displayLink = CADisplayLink(target: self, selector: #selector(willRefreshDisplay(_:)))
        self.displayLink?.preferredFramesPerSecond = Config.CURRENT_TIME_REFRESH_RATE
        self.displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc func willRefreshDisplay(_ displayLink: CADisplayLink) {
        let now = Date()
        self.currentTimeLabel.text = self.currentTimeFormat.string(from: now)
        
        self.sensorDataLock.lock()
        let sensorValues = NSMutableString("■Sensors\n")
        if let sensor = self.sensorAcceleration {
            sensorValues.append("Acceleration:\n")
            sensorValues.append("x: \(sensor.ax)\n")
            sensorValues.append("y: \(sensor.ay)\n")
            sensorValues.append("z: \(sensor.az)\n")
        }
        if let sensor = self.sensorGravity {
            sensorValues.append("Gravity:\n")
            sensorValues.append("x: \(sensor.gx)\n")
            sensorValues.append("y: \(sensor.gy)\n")
            sensorValues.append("z: \(sensor.gz)\n")
        }
        if let sensor = self.sensorRotationRate {
            sensorValues.append("RotationRate:\n")
            sensorValues.append("x: \(sensor.rrb)\n")
            sensorValues.append("y: \(sensor.rrg)\n")
            sensorValues.append("z: \(sensor.rra)\n")
        }
        if let sensor = self.sensorOrientationAngle {
            sensorValues.append("OrientationAngle:\n")
            sensorValues.append("roll: \(sensor.oag)\n")
            sensorValues.append("pitch: \(sensor.oab)\n")
            sensorValues.append("yaw: \(sensor.oaa)\n")            
        }
        self.sensorValueLabel.text = String(sensorValues)
        self.sensorDataLock.unlock()
    }
    
    func stopCurrentTimeCheckTimer() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}
