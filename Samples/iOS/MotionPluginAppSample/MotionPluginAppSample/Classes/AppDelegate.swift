//
//  AppDelegate.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2021/02/03.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, BLECentralManagerStateDelgate {

    var window: UIWindow?
    let bleManager = BLECentralManager()
    
    weak var activeVC: MainViewController?
    
    var isForeground: Bool = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("didFinishLaunchingWithOptions - AppDelegate")
        
        // User Notification Center
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.sound, .alert]) { (result, error) in
            if let error = error {
                print("Request authorization error. \(error.localizedDescription)")
                return
            }
            print("Reuqest authorization result: \(result)")
        }
        self.bleManager.removeNotifyAll()
        self.bleManager.stateDelegate = self
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("applicationWillResignActive - AppDelegate")
        self.isForeground = false
        if self.bleManager.connectedPeripherals.count >= 1 {
            self.bleManager.setNotifyAction()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("applicationDidBecomeActive - AppDelegate")
        self.isForeground = true
        print("bleManager connectedPeripherals count: \(self.bleManager.connectedPeripherals.count)")
        if self.bleManager.connectedPeripherals.count == 0 {
            DispatchQueue.main.async { [weak self] in
                print("The connected peripheral is empty.")
                self?.activeVC?.returnToMainView()
            }
        }
    }
    
    //MARK:- BLECentralManagerStateDelgate
    func manager(_ manager: BLECentralManager, didUpdateState: CBManagerState) {}
    
    func managerAllDevicesDisconnected(_ manager: BLECentralManager) {
        print("managerAllDevicesDisconnected - BLECentralManagerStateDelgate")
        DispatchQueue.main.async { [weak self] in
            self?.activeVC?.deviceDisconnected()
        }
    }

}

