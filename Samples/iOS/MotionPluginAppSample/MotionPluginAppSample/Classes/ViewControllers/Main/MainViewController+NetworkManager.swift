//
//  MainViewController+NetworkManager.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Network
import Intdash

extension MainViewController {
    
    func startConnection() {
        self.connection?.cancel()
        self.packetLossUnitsCnt = 0
        guard let str = self.inputPortTextField.text, let num = Int(str), num <= 65535, let port = NWEndpoint.Port(rawValue: NWEndpoint.Port.RawValue(num)) else {
            AlertDialogView.showAlert(viewController: self, message: "The port number should be between 0 and 65535.")
            return
        }
        print("startConnection")
        self.connection = NWConnection(host: "localhost", port: port, using: .udp)
        self.connection?.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .ready:
                print("connection ready")
                self.setPortNumber(value: num)
            case .waiting(let error):
                print("connection waiting. \(error.localizedDescription)")
            case .failed(let error):
                print("connection failed. \(error.localizedDescription)")
            default: break
            }
            print("stateUpdateHandler newState: \(newState)")
            self.connectionState = newState
        }
        self.connection?.start(queue: .global())
    }
    
    func stopConnection() {
        print("stopConnection")
        self.connection?.cancel()
        self.connection = nil
    }
    
    func sendMessage(data: Data) {
        let completion = NWConnection.SendCompletion.contentProcessed { [weak self] (error) in
            if let error = error {
                print("Send data error. \(error.localizedDescription)")
                guard self?.app.isForeground == false else { return } // Background時のみ処理
                self?.packetLossUnitsCnt += 1
                if self!.packetLossUnitsCnt >= Config.PACKET_LOSS_UNTIL_BLUETOOTH_DISCONNECTION {
                    print("Automatic Bluetooth disconnect.")
                    self?.automaticBluetoothDisconnect()
                    return
                }                
                return
            }
            //NSLog("Successful data transmission. \(data.count) bytes")
        }
        self.connection?.send(content: data, completion: completion)
    }
    
    func disconnectedWithMessage() {
        let strs = NSMutableString()
        strs.append("{")
        strs.append("\n  \"end\": \"true\"")
        strs.append("\n}")
        let message = String(strs)
        guard let messageData = message.data(using: .utf8) else { return }
        self.sendMessage(data: messageData)
        self.stopConnection()
        
    }
}
