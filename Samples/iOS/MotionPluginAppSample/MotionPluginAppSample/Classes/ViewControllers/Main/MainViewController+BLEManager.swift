//
//  MainViewController+BLEManager.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth
import Intdash

extension MainViewController: BLECentralManagerValueDelegate {
    
    func setupBLEManager() {
        self.app.bleManager.valueDelegate = self
    }
    
    func manager(_ manager: BLECentralManager, peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // ToDo:ここでタイムスタンプ保持？もしくはデータから取得する可能性あり
        // 基本的にはMotion側でDate()で取れる端末時間を元にNTPサーバーと同期を行っているのでDate()を扱うことを推奨
        // 端末時間と送信元デバイスとの伝送遅延を考慮したタイムスタンプであると良い。
        let time = Date().timeIntervalSince1970
        
        if let error = error {
            print("didUpdateValueFor characteristic error: \(error.localizedDescription) - CBPeripheralDelegate")
            return
        }
        guard let data = characteristic.value else { return }
        //NSLog("Received \(data) bytes of data.")
        guard let message = String(data: data, encoding: .utf8) else {
            print("Failed to convert message.")
            return
        }
        //NSLog("didReceived Message: \(message)")
        self.frameRateCalc.step()
        let newMessage = "\(message)\n↓\nTime: \(self.dateFormatter.string(from: Date()))"
         
         guard let dic = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
             print("Failed to decode data.")
             return
         }
        
        DispatchQueue.main.async {
            self.messageLabel.text = "Fps: \(self.frameRateCalc.getFps())\n\n" + newMessage
        }
        
        DispatchQueue.global().async {
            if let vYaw = dic["yaw"] as? NSNumber,
                let vPitch = dic["pitch"] as? NSNumber,
                let vRoll = dic["roll"] as? NSNumber,
                let vX = dic["x"] as? NSNumber,
                let vY = dic["y"] as? NSNumber,
                let vZ = dic["z"] as? NSNumber {
                let yaw = vYaw.floatValue
                let pitch = vPitch.floatValue
                let roll = vRoll.floatValue
                let x = vX.floatValue
                let y = vY.floatValue
                let z = vZ.floatValue
                let angle = GeneralSensorOrientationAngle(oaa: yaw, oab: pitch, oag: roll).toData()
                let gyro = GeneralSensorRotationRate(rra: x, rrb: y, rrg: z).toData()
                let string = try! IntdashData.DataString(id: "Test-Message-ID", data: "TestMessage")
                // 送信対象データの生成方法
                guard let data = try? IntdashPacketHelper.generatePackets(units: [angle, gyro, string]) else {
                    print("Failed to convert unit.")
                    return
                }
                let strs = NSMutableString()
                strs.append("{")
                strs.append("\n  \"t\": \"\(time)\",")
                strs.append("\n  \"d\": \"\(data.base64EncodedString())\"")
                strs.append("\n}")
                let message = String(strs)
                guard let messageData = message.data(using: .utf8) else { return }
                self.sendMessage(data: messageData)
            }
        }
        
    }
}
