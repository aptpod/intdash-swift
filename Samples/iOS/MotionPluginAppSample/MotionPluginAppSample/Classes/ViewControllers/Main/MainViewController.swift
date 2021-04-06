//
//  MainViewController.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth
import Network

class MainViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "mainView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK:- Bluetooth
    var targetPeripheral: CBPeripheral?
    
    //MARK:- Network
    var connection: NWConnection?
    var connectionState: NWConnection.State? = nil {
        didSet {
            DispatchQueue.main.async {
                var message = ""
                if let state = self.connectionState {
                    switch state {
                    case .ready:
                        message = "Successfully opened the port."
                    case .preparing:
                        message = "Preparing to open the port."
                    case .setup:
                        message = "Setting up the port."
                    case .cancelled:
                        message = "Port is not connected..."
                    default:
                        message = "Failed to open the port."
                    }
                }
                self.connectionStatusLabel.text = message
            }
        }
    }
    var packetLossUnitsCnt: UInt64 = 0
        
    //MARK:- ViewEvents
    @IBOutlet weak var messageLabel: UILabel!
    let frameRateCalc = FrameRateCalculator()
    var dateFormatter: DateFormatter!
    @IBOutlet weak var inputPortTextField: UITextField!
    @IBOutlet weak var enablePortSwitch: UISwitch!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    
    @IBOutlet weak var motionIconBtn: UIButton!
    
    //MARK:- OtherInfoTimer
    var sendNameTimer: Timer?
    
    //MARK:- viewDidload
    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad - MainViewController")
        self.app.activeVC = self
        
        guard self.targetPeripheral != nil else {
            print("Target peripheral not found.")
            self.returnToMainView()
            return
        }
        
        self.navigationItem.title = self.targetPeripheral?.name ?? Config.DEVICE_NAME_NOT_FOUND_NAME
        
        self.setupViewEvents()
        self.setupBLEManager()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    //MARK:- willEnterForeground
    @IBAction func willEnterForeground(_ notification: Notification) {
        print("willEnterForeground - MainViewController")
        self.packetLossUnitsCnt = 0
    }
    
    //MARK:- didEnterBackground
    @IBAction func didEnterBackground(_ notification: Notification) {
        print("didEnterBackground - MainViewController")
    }
    
    func returnToMainView() {
        print("returnToMainView")
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func deviceDisconnected() {
        print("deviceDisconnected")
        /// ToDo
        /// デバイスとの接続が解除されたら接続解除メッセージを送る
        self.disconnectedWithMessage()
        AlertDialogView.showAlert(viewController: self, message: "Disconnected from [ \(Config.TARGET_DEVICE_NAME) ]") { [weak self] in
            self?.returnToMainView()
        }
    }
    
    func launchMotionApp() {
        var urlComponents = URLComponents()
        urlComponents.scheme = Config.MOTION_APP_SCHEME
        if let url = urlComponents.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { (result) in
                print("launchMainApp result: \(result)")
            }
        } else {
            if let url = URL(string: Config.MOTION_APP_STORE_LINK) {
                UIApplication.shared.open(url, options: [:]) { (result) in
                    print("open app store page result: \(result)")
                }
            }
        }
    }
    
    func automaticBluetoothDisconnect() {
        self.stopConnection()
        AlertDialogView.showAlert(viewController: self, message: "The Bluetooth connection was disconnected because data could not be sent to [ \(Config.MOTION_APP_NAME) ] for a long time.") { [weak self] in
            print("The Bluetooth connection was disconnected because data could not be sent to [ \(Config.MOTION_APP_NAME) ] for a long time.")
            self?.returnToMainView()
        }
        if let peripheral = self.targetPeripheral {
            self.app.bleManager.diconnect(peripheral: peripheral)
        }
        self.setNotify()
    }
    
    func setNotify() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Config.USER_NOTIFICATION_REQUEST_ID])
        
        let categoryId = "mainViewControllerCategory"
        
        let content = UNMutableNotificationContent()
        content.title = "Disconnected from [ \(Config.TARGET_DEVICE_NAME) ]"
        content.subtitle = ""
        content.body = "The Bluetooth connection was disconnected because data could not be sent to [ \(Config.MOTION_APP_NAME) ] for a long time."
        content.sound = .default
        content.categoryIdentifier = categoryId
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Config.INTERVAL_SHOW_USER_NOTIFICATION, repeats: false)
        let request = UNNotificationRequest(identifier: Config.USER_NOTIFICATION_REQUEST_ID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - MainViewController")
        self.frameRateCalc.start()
        self.startOtherInfoTimer()
        self.enablePortSwitchValueChanged(self.enablePortSwitch)
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewDidDisappear - MainViewController")
        self.navigationController?.navigationBar.backItem?.title = "Disconnect"
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
        if let peripheral = self.targetPeripheral {
            self.app.bleManager.diconnect(peripheral: peripheral)
        }
        self.frameRateCalc.stop()
        self.stopOtherInfoTimer()
        self.stopConnection()
    }
    
    deinit {
        print("deinit - MainViewController")
    }
}
