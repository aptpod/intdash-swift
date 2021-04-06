//
//  ViewController.swift
//  BluetoothDeviceSample
//
//  Created by Ueno Masamitsu on 2021/02/03.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion

let kServiveUUID = "1234"
let kCharacteristcUUID = "ABCD"

let kCoreMotionFrameRate: TimeInterval = 20
let kTimerFrameRate: TimeInterval = 20

class ViewController: UIViewController, CBPeripheralManagerDelegate, CBPeripheralDelegate {
    
    var charcteristicUUID: CBUUID!
    var properties: CBCharacteristicProperties!
    var permissions: CBAttributePermissions!
    var characteristic: CBMutableCharacteristic!
    
    var serviceUUID : CBUUID!
    var service: CBMutableService!
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral?
    
    var dateFormatter: DateFormatter!
    @IBOutlet weak var messageLabel: UILabel!
    
    let frameRateCalc = FrameRateCalculator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        NSLog("viewDidLoad - AppCommunicationBluetoothTest")
        self.setupBluetooth()
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "YYYY/MM/dd HH:mm:ss.SSS"
    }
    
    var timer: Timer?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // macOS Catalyst
        #if targetEnvironment(macCatalyst)
        self.timer = Timer.scheduledTimer(withTimeInterval: 1/kTimerFrameRate, repeats: true, block: { [weak self] (_) in
            self?.frameRateCalc.step()
            let strs = NSMutableString()
            strs.append("{")
            strs.appendFormat("\n  \"yaw\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"pitch\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"roll\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"x\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"y\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"z\": %f, ", Float.random(in: 0..<180))
            strs.appendFormat("\n  \"time\": \"%@\"", self!.dateFormatter.string(from: Date()))
            strs.append("\n}")
            let message = String(strs)
            self?.messageLabel.text = "Fps: \(self!.frameRateCalc.getFps())\n\n" + message
            guard let data = message.data(using: .utf8) else { return }
            self?.sendMessage(data: data)
        })
        #endif
        
        // CoreMotion
        self.setupCoreMotion()
        
        // FrameRate Calc
        self.frameRateCalc.start()
    }
    
    // MARK:- Bluetooth
    func setupBluetooth() {
        self.charcteristicUUID = CBUUID(string: kCharacteristcUUID)
        self.properties = [.notify, .read, .write]
        self.permissions = [.readable, .writeable]
        self.characteristic = CBMutableCharacteristic(type: charcteristicUUID, properties: properties, value: nil, permissions: permissions)
        
        self.serviceUUID = CBUUID(string: kServiveUUID)
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [self.characteristic]
        self.service = service
        
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: .global(), options: nil)
        self.startAdvertising()
    }
    
    func sendMessage(data: Data) {
        if let characteristic = self.characteristic {
            self.peripheralManager?.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
        }
    }
    
    func startAdvertising() {
        if self.peripheralManager?.isAdvertising == false {
            let advertisementData: Dictionary = [CBAdvertisementDataServiceUUIDsKey: [serviceUUID]]
            self.peripheralManager?.startAdvertising(advertisementData)
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("peripheralManagerDidUpdateState - CBPeripheralManagerDelegate")
        switch peripheral.state {
        case .poweredOn:
            print("bluetooth poweredOn")
            peripheral.add(self.service)
            self.startAdvertising()
        case .poweredOff:
            print("bluetooth poweredOff")
            self.peripheralManager = nil
        default: break
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("peripheralManagerDidStartAdvertising")
        if let error = error {
            print("DidStartAdvertising error. \(error.localizedDescription)")
        }else{
            print("DidStartAdvertising ok.")
        }
    }
    
    //MARK:- CoreMotion
    let motionManager = CMMotionManager()
    
    func setupCoreMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1 / kCoreMotionFrameRate
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let motion = motion else { return }
            self?.frameRateCalc.step()
            let strs = NSMutableString()
            strs.append("{")
            strs.appendFormat("\n  \"yaw\": %f, ", motion.attitude.yaw * 180 / Double.pi)
            strs.appendFormat("\n  \"pitch\": %f, ", motion.attitude.pitch * 180 / Double.pi)
            strs.appendFormat("\n  \"roll\": %f, ", motion.attitude.roll * 180 / Double.pi)
            strs.appendFormat("\n  \"x\": %f, ", motion.rotationRate.x * 180 / Double.pi)
            strs.appendFormat("\n  \"y\": %f, ", motion.rotationRate.y * 180 / Double.pi)
            strs.appendFormat("\n  \"z\": %f, ", motion.rotationRate.z * 180 / Double.pi)
            strs.appendFormat("\n  \"time\": \"%@\"", self!.dateFormatter.string(from: Date()))
            strs.append("\n}")
            let message = String(strs)
            self?.messageLabel.text = "Fps: \(self!.frameRateCalc.getFps())\n\n" + message
            guard let data = message.data(using: .utf8) else { return }
            self?.sendMessage(data: data)
        }
    }
    
}
