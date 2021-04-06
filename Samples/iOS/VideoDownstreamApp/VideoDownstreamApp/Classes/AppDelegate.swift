//
//  AppDelegate.swift
//  VideoDownstreamApp
//
//  Created by Ueno Masamitsu on 2021/02/03.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var activeVC: UIViewController?
    
    var edgeList: [EdgeItem] = []
    
    var targetEdge: EdgeItem?
    var targetChannel: Int = Config.INTDASH_TARGET_CHANNEL_DEFAULT

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        print("didFinishLaunchingWithOptions - AppDelegate")
        
        // Log Level.
        IntdashLog.shared.level = Config.INTDASH_LOG_LEVEL
        
        // Token has expired.
        _ = NotificationCenter.default.addObserver(forName: IntdashAPIManager.didDetectTokenExpired, object: nil, queue: nil) { [weak self] _ in
            print("didDetectTokenExpired - AppDelegate")
            self?.signOut()
        }
        
        return true
    }
    
    public func signOut() {
        DispatchQueue.main.async { [weak self] in
            IntdashAPIManager.shared.signOut()
            self?.activeVC?.dismiss(animated: true, completion: nil)
            self?.activeVC = nil
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        print("applicationWillResignActive - AppDelegate")
        // Sleep on
        application.isIdleTimerDisabled = false
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("applicationDidBecomeActive - AppDelegate")
        // Sleep off
        application.isIdleTimerDisabled = true
    }

}

