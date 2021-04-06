//
//  FileListViewController.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
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
        var title: String { return "S2E-\(self.measId.prefix(5))" }
        var measPath: String { return "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)"}
    }
    var measDataList: [MeasData] = []
    
    // Intdash Client
    var intdashClient: IntdashClient?
    var upstreamId: Int?
    var isRunning: Bool{ return intdashClient != nil }
    var resendCheckCompletion: ((Bool)->())?
    var sectionCnt = 0
    var sectionSize = 0
    var isReadySendUnitReceivedAck: Bool {
        return sectionSize == sectionCnt
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
                    guard let fileManager = try? IntdashDataFileManager.load(parentPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)"),
                        let baseTime = fileManager.baseTime else {
                        print("Failed to load IntdashDataFileManager.")
                        return
                    }
                    let ntpTime = fileManager.baseTime2
                    var duration = fileManager.duration
                    let isUploaded = fileManager.isUploaded
                    let dataSize = fileManager.dataSize
                    print("BaseTime:\(ntpTime ?? baseTime), duration:\(duration ?? -1), isUploaded:\(isUploaded)")
                    if duration == nil {
                        duration = TimeInterval(fileManager.getDataDuration())
                        print("Update duration. \(duration!)")
                        try? fileManager.setDuration(duration: duration)
                    }
                    let data = MeasData.init(measId: measId, edgeUUID: edgeUUID, baseTime: baseTime, duration: duration, ntpTime: ntpTime, isUploaded: isUploaded, dataSize: dataSize)
                    self?.measDataList.append(data)
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
