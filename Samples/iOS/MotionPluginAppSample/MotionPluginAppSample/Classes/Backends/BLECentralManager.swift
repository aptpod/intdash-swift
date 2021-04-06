//
//  BLECentralManager.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import UserNotifications

enum BLECentralManagerError: Error {
    case serviceUuidNotFound
    case characteristicUuidNotFound
}

protocol BLECentralManagerValueDelegate: NSObjectProtocol {
    func manager(_ manager: BLECentralManager, peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
}

protocol BLECentralManagerDeviceDelegate: NSObjectProtocol {
    func manager(_ manager: BLECentralManager, didUpdateState: CBManagerState)
    func manager(_ manager: BLECentralManager, didUpdateScanningDevices devices: [PeripheralDevice])
}

protocol BLECentralManagerStateDelgate: NSObjectProtocol {
    func manager(_ manager: BLECentralManager, didUpdateState: CBManagerState)
    func managerAllDevicesDisconnected(_ manager: BLECentralManager)
}

struct PeripheralDevice {
    var peripheral: CBPeripheral
    var rssi: NSNumber
}

class BLECentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, UNUserNotificationCenterDelegate {
    
    public weak var stateDelegate: BLECentralManagerStateDelgate?
    public weak var valueDelegate: BLECentralManagerValueDelegate?
    public weak var deviceDelegate: BLECentralManagerDeviceDelegate?
     
    public private(set) var centralManager: CBCentralManager!
    public private(set) var isScanning: Bool = false
    private var scanningServices: [String]?
    
    var targetServiceUUID: CBUUID?
    var targetCharcteristicUUID: CBUUID!
        
    var scannedDevices: [UUID:PeripheralDevice] = [:]
    var connectedPeripherals: [UUID:CBPeripheral] = [:]
    
    var connectionRequestCompletion: ((Bool, Error?) -> ())?
        
    public override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @IBAction func willEnterForeground(_ notification: Notification) {
        print("willEnterForeground - BLECentralManager")
        if self.isScanning {
            self.startScanning(services: self.scanningServices)
        }
    }
    
    @IBAction func didEnterBackground(_ notification: Notification) {
        print("didEnterBackground - BLECentralManager")
        if self.isScanning {
            self.centralManager.stopScan()
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOn:
            print("bluetooth poweredOn - BLECentralManager")
            if self.isScanning {
                self.startScanning(services: self.scanningServices)
            }
        case .poweredOff:
            print("bluetooth poweredOff - BLECentralManager")
            self.disconnectAll()
        default:
            print("bluetooth state did updated. \(central.state)")
        }
        self.stateDelegate?.manager(self, didUpdateState: central.state)
        self.deviceDelegate?.manager(self, didUpdateState: central.state)
    }
    
    func startScanning(services: [String]? = nil) {
        self.isScanning = true
        self.scanningServices = services
        guard self.centralManager.state == .poweredOn else { return }
        let uuids: [CBUUID]? = services?.map { CBUUID(string: $0) }
        self.centralManager.scanForPeripherals(withServices: uuids, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        print("startScanning. services: \(services ?? []) - BLECentralManager")
    }
    
    func stopScanning() {
        self.isScanning = false
        self.centralManager.stopScan()
        print("stopScanning - BLECentralManager")
    }
    
    func connect(peripheral: CBPeripheral, targetServiceUUID: String, targetCharcteristicUUID: String, completion: @escaping ((Bool, Error?) -> ())) {
        self.targetServiceUUID = CBUUID(string: targetServiceUUID)
        self.targetCharcteristicUUID = CBUUID(string: targetCharcteristicUUID)
        self.connectionRequestCompletion = completion
        self.centralManager.connect(peripheral, options: nil)
    }
    
    func diconnect(peripheral: CBPeripheral) {
        if connectedPeripherals.keys.contains(peripheral.identifier) {
            self.centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func disconnectAll() {
        for peripheral in self.connectedPeripherals {
            self.centralManager.cancelPeripheralConnection(peripheral.value)
        }
        self.connectedPeripherals.removeAll()
        self.stateDelegate?.managerAllDevicesDisconnected(self)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        //print("didDiscover peripheral - CBCentralManagerDelegate")
        if !self.scannedDevices.keys.contains(peripheral.identifier) {
            print("Peripheral Name: \(peripheral.name ?? "Unknown"), \(peripheral.identifier)")
            self.scannedDevices[peripheral.identifier] = PeripheralDevice(peripheral: peripheral, rssi: RSSI)
        } else {
            self.scannedDevices[peripheral.identifier]?.rssi = RSSI
        }
        self.deviceDelegate?.manager(self, didUpdateScanningDevices: Array(self.scannedDevices.values))
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect peripheral - CBCentralManagerDelegate")
        peripheral.delegate = self
        self.connectedPeripherals[peripheral.identifier] = peripheral
        peripheral.discoverServices([])
        self.setNotifyAction()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral peripheral([ \(peripheral.name ?? Config.DEVICE_NAME_NOT_FOUND_NAME) ], \(peripheral.identifier)) - CBCentralManagerDelegate")
        if connectedPeripherals.keys.contains(peripheral.identifier) {
            self.connectedPeripherals.removeValue(forKey: peripheral.identifier)
        }
        if self.connectedPeripherals.count == 0 {
            self.setNotifyDisconnected()
            self.stateDelegate?.managerAllDevicesDisconnected(self)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("didDiscoverServices error: \(error.localizedDescription) - CBPeripheralDelegate")
            return
        }
        var isFound: Bool = false
        if let services = peripheral.services {
            for service in services {
                print("service: \(service.uuid)")
                if service.uuid == self.targetServiceUUID {
                    isFound = true
                    print("Target service uuid found. \(service.uuid)")
                    peripheral.discoverCharacteristics([self.targetCharcteristicUUID], for: service)
                }
            }
        }
        guard !isFound else { return }
        self.connectionRequestCompletion?(false, BLECentralManagerError.serviceUuidNotFound)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("didDiscoverCharacteristicsFor service error: \(error.localizedDescription) - CBPeripheralDelegate")
            return
        }
        var isFound: Bool = false
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("characteristic: \(characteristic.uuid)")
                if characteristic.uuid == self.targetCharcteristicUUID {
                    isFound = true
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
        self.connectionRequestCompletion?(isFound, isFound ? nil : BLECentralManagerError.characteristicUuidNotFound)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.valueDelegate?.manager(self, peripheral: peripheral, didUpdateValueFor: characteristic, error: error)
    }
    
    // MARK:- UserNotification
    enum NotificationActionType: String {
        case disconnect
        case cancel
    }
    
    public func setNotifyAction() {
        print("setNotifyAction")
        let disconnect = UNNotificationAction(identifier: NotificationActionType.disconnect.rawValue,
                                              title: "Disconnect", options: [.foreground])
        let cancel = UNNotificationAction(identifier: NotificationActionType.cancel.rawValue, title: "Cancel", options: [.foreground])
        let categoryId = "bleCentralManagerCategory"
        let category = UNNotificationCategory(identifier: categoryId, actions: [disconnect, cancel], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
        
        let content = UNMutableNotificationContent()
        content.title = "Connecting to [ \(Config.TARGET_DEVICE_NAME) ]"
        content.subtitle = ""
        content.body = "※Battery life may be significantly reduced while connected to [ \(Config.TARGET_DEVICE_NAME) ]"
        content.sound = .default
        content.categoryIdentifier = categoryId
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Config.INTERVAL_SHOW_USER_NOTIFICATION, repeats: false)
        let request = UNNotificationRequest(identifier: Config.USER_NOTIFICATION_REQUEST_ID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func setNotifyDisconnected() {
        print("setNotifyDisconnected")
        let content = UNMutableNotificationContent()
        content.title = ""
        content.subtitle = ""
        content.body = "Disconnected from [ \(Config.TARGET_DEVICE_NAME) ]"
        content.sound = .default

        let request = UNNotificationRequest(identifier: Config.USER_NOTIFICATION_REQUEST_ID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    public func removeNotifyAll() {
        print("removeNotifyAll")
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Config.USER_NOTIFICATION_REQUEST_ID])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("userNotificationCenter didReceive: \(response.actionIdentifier)")
        switch response.actionIdentifier {
        case NotificationActionType.disconnect.rawValue:
            self.disconnectAll()
        default: break
        }
        completionHandler()
    }
    
    public func dispose() {
        self.centralManager = nil
    }
    
    deinit {
        print("deinit - BLEManager")
    }
}
