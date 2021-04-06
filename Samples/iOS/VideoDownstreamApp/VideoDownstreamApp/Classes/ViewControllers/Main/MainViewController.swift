//
//  MainViewController.swift
//  VideoDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import MapKit
import Intdash

fileprivate let kViewTitle = "Main"

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
    
    // Downstream Data
    var downstreamIds = [Int]()
    var downstreamId = -1
    
    // Sensor Data
    var sensorDataLock = NSLock()
    var sensorAcceleration: GeneralSensorAcceleration?
    var sensorGravity: GeneralSensorGravity?
    var sensorRotationRate: GeneralSensorRotationRate?
    var sensorOrientationAngle: GeneralSensorOrientationAngle?
    
    var currentTimeFormat: DateFormatter!
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - MainViewController")
        self.navigationItem.title = kViewTitle
        // View Events
        self.setupViewEvents()
    }
    
    //MARK:- viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear - MainViewController")
    }
    
    //MARK:- viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear - MainViewController")
        // Stop
        self.stopStream()
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - MainViewController")
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - MainViewController")
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - MainViewController")
    }
    
    //MARK:- Start Stream
       func startStream() {
           if self.intdashClient == nil {
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
