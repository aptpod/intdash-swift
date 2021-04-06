//
//  DeviceListViewController+TableView.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

fileprivate let kCellIdentifier = "defaultCell"

extension DeviceListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        defer { self.deviceListLock.unlock() }
        self.deviceListLock.lock()
        return self.scanningDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        self.deviceListLock.lock()
        let device = self.scanningDevices[indexPath.row]
        self.deviceListLock.unlock()
        
        var cell: UITableViewCell!
        cell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier, for: indexPath)
        if let customCell = cell as? DeviceListViewTableViewCell {
            customCell.deviceNameLabel.text = "[ \(device.peripheral.name ?? Config.DEVICE_NAME_NOT_FOUND_NAME) ]"
            customCell.deviceIdLabel.text = "\(device.peripheral.identifier)"
            customCell.deviceStateLabel.text = String(format: "RSSI: %d", device.rssi.intValue)
        }
            
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.deviceListLock.lock()
        let device = self.scanningDevices[indexPath.row]
        self.deviceListLock.unlock()
        self.connectDevice(peripheral: device.peripheral)
    }
}

class DeviceListViewTableViewCell: UITableViewCell {
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var deviceIdLabel: UILabel!
    @IBOutlet weak var deviceStateLabel: UILabel!
}
