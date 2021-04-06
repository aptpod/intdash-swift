//
//  FileListViewController.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

class FileListViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "fileListView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var tableView: UITableView!
    
    // Measurement Data
    struct MeasData {
        var measId: String
        var edgeUUID: String
        var baseTime: TimeInterval
        var duration: TimeInterval?
        var ntpTime: TimeInterval?
        var isUploaded: Bool
        var dataSize: UInt64

        var isNtpTime: Bool { return self.ntpTime != nil }
        var title: String { return "UUID:\(self.measId.prefix(8))..." }
        var measPath: String { return "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)"}
        var isSensor: Bool = false
        var isGPS: Bool = false
    }
    var measDataList: [MeasData] = []
    
    // Intdash Client
    var intdashClient: IntdashClient?
    var sensorUpstreamId: Int?
    var gpsUpstreamId: Int?
    var upstreamIds = [Int]()
    var isRunning: Bool{ return intdashClient != nil }
    var resendCheckCompletion: ((Bool)->())?
    var sensorSectionCnt = 0
    var sensorSectionSize = 0
    var gpsSectionCnt = 0
    var gpsSectionSize = 0
    var receivedFinalCnt = 0
    func isReadyToSend(streamId: Int) -> Bool? {
        switch streamId {
        case self.sensorUpstreamId:
            return sensorSectionCnt == sensorSectionSize
        case self.gpsUpstreamId:
            return gpsSectionCnt == gpsSectionSize
        default: return nil
        }
    }
    
    // Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    
    let baseTimeFormat = DateFormatter()
    let endTimeFormat = DateFormatter()
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - FileListViewController")
        // View Events
        self.setupViewEvents()
        // TableView
        self.setupTableView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear() - FileListViewController")
        self.loadMeasDataList()
    }
    
    func updateNavigationBarTitle() {
        self.navigationItem.title = "FileList [ \(self.measDataList.count) ]"
    }
    
    func loadMeasDataList() {
        guard let edgeUUID = IntdashAPIManager.shared.singInEdgeUuid else {
            print("Failed to get edge uuid.")
            return
        }
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async { [weak self] in
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)") {
                print("Measurement data size: \(contents.count)")
                contents.forEach { measId in
                    print("MeasID: \(measId)")
                    if let dataTypes = try? fm.contentsOfDirectory(atPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)") {
                        var measData: MeasData?
                        dataTypes.forEach { type in
                            print("DataType: \(type)")
                            guard let fileManager = try? IntdashDataFileManager.load(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)/\(type)"),
                                let baseTime = fileManager.baseTime else {
                                print("Failed to load IntdashDataFileManager.")
                                return
                            }
                            let ntpTime = fileManager.baseTime2
                            var duration = fileManager.duration
                            let isUploaded = fileManager.isUploaded
                            let dataSize = fileManager.dataSize
                            print("[\(type)] BaseTime:\(ntpTime ?? baseTime), duration:\(duration ?? -1), isUploaded:\(isUploaded)")
                            if duration == nil {
                                duration = TimeInterval(fileManager.getDataDuration())
                                print("Update duration. \(duration!)")
                                try? fileManager.setDuration(duration: duration)
                            }
                            if var data = measData {
                                if data.ntpTime == nil { data.ntpTime = ntpTime }
                                if data.duration == nil { data.duration = duration }
                                if data.isUploaded != isUploaded { data.isUploaded = false }
                                data.dataSize += dataSize
                                measData = data
                            } else {
                                measData = MeasData.init(measId: measId, edgeUUID: edgeUUID, baseTime: baseTime, duration: duration, ntpTime: ntpTime, isUploaded: isUploaded, dataSize: dataSize)
                            }
                            switch type {
                            case "sensor": measData?.isSensor = true
                            case "gps": measData?.isGPS = true
                            default: break
                            }
                        }
                        if let data = measData {
                            self?.measDataList.append(data)
                        }
                    }
                }
                self?.measDataList.sort { d1, d2 in d1.baseTime > d2.baseTime }
            }
            DispatchQueue.main.async {
                self?.loadingDialog?.stopAnimating()
                self?.loadingDialog = nil
                self?.tableView.reloadData()
            }
        }
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - FileListViewController")
    }
}
