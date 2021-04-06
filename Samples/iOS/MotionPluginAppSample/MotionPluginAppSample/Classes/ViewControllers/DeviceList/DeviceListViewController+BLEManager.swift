//
//  DeviceListViewController+BLEManager.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth

extension DeviceListViewController: BLECentralManagerDeviceDelegate {
    
    func setupBLEManager() {
        self.app.bleManager.deviceDelegate = self
    }
    
    //MARK:- BLECentralManagerDeviceDelegate
    func manager(_ manager: BLECentralManager, didUpdateState: CBManagerState) {
        if didUpdateState != .poweredOn {
            DispatchQueue.main.async {
                self.loadinAlertDialog = LoadingAlertDialogView(addView: self.view, showMessageLabel: true)
                self.loadinAlertDialog?.setMessage(message: "Bluetooth is not enabled.")
                self.loadinAlertDialog?.startAnimating()
            }
        } else {
            self.loadinAlertDialog?.stopAnimating()
            self.loadinAlertDialog = nil
        }
    }
    
    func manager(_ manager: BLECentralManager, didUpdateScanningDevices devices: [PeripheralDevice]) {
        defer { self.deviceListLock.unlock() }
        self.deviceListLock.lock()
        // RSSIでソート
        self.scanningDevices = devices.sorted(by: { (d1, d2) -> Bool in
            return d1.rssi.intValue > d2.rssi.intValue
        })
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func connectDevice(peripheral: CBPeripheral) {
        self.loadinAlertDialog?.stopAnimating()
        self.loadinAlertDialog = LoadingAlertDialogView(addView: self.view, showMessageLabel: false)
        self.loadinAlertDialog?.startAnimating()
        self.app.bleManager.connect(peripheral: peripheral, targetServiceUUID: Config.TARGET_SERIVCE_UUID, targetCharcteristicUUID: Config.TARGET_CHRACTERISTIC_UUID) { (result, error) in
            defer { DispatchQueue.main.async {
                self.loadinAlertDialog?.stopAnimating()
                self.loadinAlertDialog = nil
            }}
            guard result else {
                AlertDialogView.showAlert(viewController: self, message: "Failed to connect with [ \(peripheral.name ?? Config.DEVICE_NAME_NOT_FOUND_NAME) ] \(error?.localizedDescription != nil ? "\n\(error!.localizedDescription)" : "")")
                return
            }
            self.goToMainView(peripheral: peripheral)
        }
    }
}
