//
//  Config.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation

class Config {
    
    static let PLUGIN_APP_NAME = "Plugin Sample"
    
    static let TARGET_DEVICE_NAME = "BluetoothApp"
    
    static let MOTION_APP_NAME = "intdash Motion"
    static let MOTION_APP_SCHEME = "aptpod.motion"
    static let MOTION_APP_STORE_LINK = "https://itunes.apple.com/jp/app/apple-store/id1303331675?mt=8"
    
    static let TARGET_SERIVCE_UUID = "1234"
    static let TARGET_CHRACTERISTIC_UUID = "ABCD"
    
    static let DEVICE_NAME_NOT_FOUND_NAME = "Unknown"
    
    static let TIME_STRING_FORMAT = "YYYY/MM/dd HH:mm:ss.SSS"
    
    // UDP接続のデフォルトのポート番号
    static let PORT_NUMBER_DEFAULT = 12345
    
    // パケットが正しく送信できない際に、自動でBluetooth接続を解除するまでのユニット数
    static let PACKET_LOSS_UNTIL_BLUETOOTH_DISCONNECTION: UInt64 = 20 * 60 * 5
    
    // User Notification
    static let USER_NOTIFICATION_REQUEST_ID = "request"
    static let INTERVAL_SHOW_USER_NOTIFICATION: TimeInterval = 2
}
