//
//  MainViewController.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion
import MapKit
import Intdash

class MainViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "mainView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK:- ViewEvents
    @IBOutlet weak var streamControlBtn: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var sensorValueLabel: UILabel!
    
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
    var sensorUpstreamId: Int?
    var gpsUpstreamId: Int?
    var upstreamMeasurementId = ""
    var baseTime: TimeInterval = -1
    var generateSendLastDataCnt = 0
    
    // BaseTimes for Samples
    var locationBaseTime: TimeInterval = -1
    var locationSampleBaseTime: TimeInterval = -1
    var headBaseTime: TimeInterval = -1
    var headSampleBaseTime: TimeInterval = -1
    var motionBaseTime: TimeInterval = -1
    var motionSampleBaseTime: TimeInterval = -1
    func resetBaseTime() {
        self.baseTime = -1
        self.locationBaseTime = -1
        self.locationSampleBaseTime = -1
        self.headBaseTime = -1
        self.headSampleBaseTime = -1
        self.motionBaseTime = -1
        self.motionSampleBaseTime = -1
    }
    
    // FileManager for Units
    var gpsDataFileManager: IntdashDataFileManager?
    var sensorDataFileManager: IntdashDataFileManager?
    
    // Badnetwork Management
    var badNetworkLock = NSLock()
    var isRefreshingWebSocket = false
    var refreshNetworkTimeCnt: Int = 0
    
    //MARK:- GPSManager
    var locationManager = CLLocationManager()
    
    //MARK:- SensorManager
    var motionManager = CMMotionManager()
    
    //MARK:- MapView
    var userTrackingBtn: MKUserTrackingButton! 
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - MainViewController")
        self.app.activeVC = self
        // View Events
        self.setupViewEvents()
        // Map View
        self.setupMapView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("viewWillTransition - MainViewController")
        coordinator.animate(alongsideTransition: { (_) in }) { [weak self] (_) in
            // Did change device orientation.
            print("didChangeDeviceOrientation: \(self?.view.interfaceOrientation?.name ?? "NULL")")
            // GPS head
            self?.updateGpsHeadingOrientaiton()
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
        // Intdsah Client
        self.closeIntdashClient()
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - MainViewController")
        // GPS Manager
        self.setupGPSManager()
        // Sensor Manager
        self.setupSensorManager()
        // Intdash Client
        self.openIntdashClient()
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - MainViewController")
        // GPS Manager
        self.disposeGPSManager()
        // Sensor Manager
        self.disposeSensorManager()
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
    func startMeasurement() {
        guard self.intdashClient != nil else { return }
        if self.upstreamMeasurementId.isEmpty {
            // Reset System Clock.
            MySystemClock.shared.resetRtc()
            self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
            self.loadingDialog?.startAnimating()
            self.startUpstream { [weak self] result in
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                }
                guard result else { return }
                self?.updateStreamControlBtn()
            }
        } else {
            self.stopMeaurement()
        }
    }
    
    func stopMeaurement() {
        self.stopUpstream()
        self.updateStreamControlBtn()
    }
}
