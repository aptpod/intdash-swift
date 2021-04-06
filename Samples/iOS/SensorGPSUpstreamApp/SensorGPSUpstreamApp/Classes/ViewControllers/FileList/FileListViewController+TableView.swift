//
//  FileListViewController+TableView.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

fileprivate let kCellIdentifier = "defaultCell"

extension FileListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        // Date Format
        self.baseTimeFormat.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyy/MM/dd HH:mm:ss", options: 0, locale: Locale(identifier: "ja_JP"))
        self.endTimeFormat.dateFormat = DateFormatter.dateFormat(fromTemplate: "HH:mm:ss", options: 0, locale: Locale(identifier: "en_US_POSIX"))
    }
    
    //MARK:- UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.updateNavigationBarTitle()
        return self.measDataList.count
    }
    
    //MARK:- UITableViewDelegate
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier, for: indexPath)
        let data = self.measDataList[indexPath.row]
        cell.textLabel?.text = "\(data.isUploaded ? "[ UPLOADED ] " : "")\(data.title) \(data.duration != nil ? "[ \(data.duration!.durationString) ]" : "")"
        cell.detailTextLabel?.text = "[ \(data.isNtpTime ? "NTP" : "RTC") ] \(self.baseTimeFormat.string(from: Date.init(timeIntervalSince1970: data.baseTime)))-\(data.duration != nil ? self.endTimeFormat.string(from: Date.init(timeIntervalSince1970: data.baseTime+data.duration!)): ""), \(data.dataSize.dataSizeString)"
        return cell
    }
    
    // Left Button
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let data = self.measDataList[indexPath.row]
        let action = UIContextualAction(style: .normal, title: "Delete") { (_, _, completion) in
            // Delete Action
            AlertDialogView.showAlert(viewController: self, title: nil, message: "Delete [ \(data.title) ]?", boolCompletion: { [weak self] (result) in
                completion(true)
                guard result else { return }
                self?.remove(index: indexPath.row)
            })
        }
        action.backgroundColor = Config.CELL_DELETE_BTN_BG_COLOR
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func remove(index: Int) {
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async {
            let data = self.measDataList[index]
            try? FileManager.default.removeItem(atPath: data.measPath)
            DispatchQueue.main.async {
                self.loadingDialog?.stopAnimating()
                self.loadingDialog = nil
                self.measDataList.remove(at: index)
                self.tableView.deleteRows(at: [IndexPath.init(row: index, section: 0)], with: .right)
                self.updateNavigationBarTitle()
            }
        }
    }
    
    // Right Button
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let data = self.measDataList[indexPath.row]
        let action = UIContextualAction(style: .normal, title: "Upload") { (_, _, completion) in
            // Upload Action
            guard data.isUploaded else {
                completion(true)
                self.upload(index: indexPath.row)
                return
            }
            AlertDialogView.showAlert(viewController: self, title: nil, message: "[ \(data.title) ] is already uploaded. Upload again?", boolCompletion: { (result) in
                completion(true)
                guard result else { return }
                self.upload(index: indexPath.row)
            })
        }
        action.backgroundColor = Config.CELL_UPLOAD_BTN_BG_COLOR
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func upload(index: Int) {
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: true)
        self.loadingDialog?.startAnimating()
        let data = self.measDataList[index]
        DispatchQueue.global().async { [weak self] in
            self?.uploadData(measData: data, completion: { (result) in
                self?.resendCheckCompletion = nil
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                    AlertDialogView.showAlert(viewController: self!, message: result ? "Upload completed." : "There was a problem during the upload.")
                    if result {
                        self?.measDataList[index].isUploaded = true
                        do {
                            if data.isSensor {
                                let fileManager = try IntdashDataFileManager.load(parentPath: "\(data.measPath)/sensor")
                                try fileManager.setUploadFlag(flag: true)
                            }
                            if data.isGPS {
                                let fileManager = try IntdashDataFileManager.load(parentPath: "\(data.measPath)/gps")
                                try fileManager.setUploadFlag(flag: true)
                            }
                        } catch { print("Failed to set uploadFlag. \(error)" )}
                    }
                    self?.tableView?.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .automatic)
                }
            })
        }
    }
}
