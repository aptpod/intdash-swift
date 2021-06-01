//
//  MainViewController.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import Intdash

class MainViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "mainView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK:- ViewEvents
    @IBOutlet weak var streamControlBtn: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!    
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var resolutionLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    
    // Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    
    var displayLink: CADisplayLink?
    var isShowAlertDialog: Bool = false
    
    //MARK:- IntdashManager
    var intdashClient: IntdashClient?
    var webSocketLock = NSLock()
    var clockLock = NSLock()
    
    // Upstream Data
    var upstreamIds = [Int]()
    var upstreamId: Int?
    var upstreamMeasurementId = ""
    var baseTime: TimeInterval = -1
    
    // BaseTimes for Samples
    func resetBaseTime() {
        self.baseTime = -1
    }
    
    // FileManager for Units
    var intdashDataFileManager: IntdashDataFileManager?
    
    // Badnetwork Management
    var badNetworkLock = NSLock()
    var isRefreshingWebSocket = false
    var refreshNetworkTimeCnt: Int = 0
    
    //MARK:- CaptureDeviceFunc
    var captureDevice: AVCaptureDevice?
    var captureSession: AVCaptureSession?
    var captureConnection: AVCaptureConnection?
    
    var timestampFormat: DateFormatter!
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - MainViewController")
        self.app.activeVC = self
        // View Events
        self.setupViewEvents()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("viewWillTransition - MainViewController")
        coordinator.animate(alongsideTransition: { (_) in }) { [weak self] (_) in
            // Did change device orientation.
            print("didChangeDeviceOrientation: \(self?.view.interfaceOrientation?.name ?? "NULL")")
            // Capture orientation
            self?.updateCaptureOrientation()
        }
    }
    
    //MARK:- viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear - MainViewController")
        self.navigationController?.navigationBar.isHidden = true
    }
    
    //MARK:- viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear - MainViewController")
        self.navigationController?.navigationBar.isHidden = false
        // Stop
        self.stopStream()
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - MainViewController")
        // Capture
        self.startCapturing()
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - MainViewController")
        // capture
        self.stopCapturing()
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - MainViewController")
    }
    
    func goToFileListView() {
        DispatchQueue.main.async {
           if let vc = self.storyboard?.instantiateViewController(withIdentifier: FileListViewController.VIEW_IDENTIFIER) {
                self.navigationController?.pushViewController(vc, animated: true)
           }
        }
    }
    
    //MARK:- Start Stream
    func startStream() {
        if self.intdashClient == nil {
            // Reset System Clock.
            MySystemClock.shared.resetRtc()
            self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
            self.loadingDialog?.startAnimating()
            self.openIntdashClient { [weak self] (result) in
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                }
                guard result else { return }
                self?.updateStreamControlBtn()
            }
        } else {
            self.stopStream()
        }
    }
    
    func stopStream() {
        self.closeIntdashClient()
        self.updateStreamControlBtn()
    }
}
