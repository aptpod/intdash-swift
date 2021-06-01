//
//  Config.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import Intdash

class Config {
    
    /// アプリごとのOAuth2.0 Web認証用のコールバックスキーム。intdashサーバー管理者に登録を依頼してください。
    ///
    /// この値は `Info.plist` でも設定してください。※ただし`:`以降は不要です。(`example.app`のみ）
    public static let CALLBACK_URL_SCHEME: String = "example.app://oauth2/callback"
    /*
     |Key                  |Type       |Value                       |
     |---------------------|-----------|----------------------------|
     |- URL types          |Array      |                            |
     |  - Item 0 (Viewer)  |Dictionary |                            |
     |    - Document Role  |String     |Viewer                      |
     |    - URL identifier |String     |$(PRODUCT_BUNDLE_IDENTIFIER)|
     |    - URL Schemes    |Array      |                            |
     |      - Item 0       |String     |example.app                 |
    */
    
    // Intdash Serivce Options
    public static let INTDASH_LOG_LEVEL: IntdashLogLevel = .info
    public static let INTDASH_TARGET_CHANNEL: Int = 1
    // If you want to save the data to the server, you must turn on this flag.
    public static let INTDASH_IS_SAVE_TO_SERVER = true
    public static let INTDASH_WAIT_FOR_SEND_UNITS_INTERVAL: TimeInterval = 0.001
    public static let INTDASH_UNITS_RESEND_TIME_INTERVAL: Int = 5
    
    // Intdash Data File Manager
    public static let INTDASH_DATA_FILE_PARENT_PATH = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    
    // The number of seconds to refresh the socket when data is stuck.
    public static let BADNETWORK_REFRESH_TIME: Int = 10
    
    // Capture Device
    public static let CAMERA_DEVICE_TYPE: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    public static let CAMERA_CAPTURE_POSITION: AVCaptureDevice.Position = .back
    public static let CAMERA_PIXEL_FORMAT_TYPE = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    public static let CAMERA_CAPTURE_PRESET: AVCaptureSession.Preset = .low
    
    // Jpeg
    public static let JPEG_COMPRESS_QUALITY: CGFloat = 0.1
    
    // View Events
    static let CURRENT_TIME_REFRESH_RATE: Int = 2
    static let TIMESTAMP_FORMAT_STRING = "HH:mm:ss.SSS"
    static let TIMESTAMP_DEFAULT_STRING = "00:00:00.000"
    
    static let BUTTON_ACTIVE_TEXT_COLOR: UIColor = UIColor.init(red: 215/255.0, green: 62/255.0, blue: 133/255.0, alpha: 1.0)
    static let BUTTON_DEACTIVE_TEXT_COLOR: UIColor = UIColor.white
    
    // File List
    public static let CELL_DELETE_BTN_BG_COLOR: UIColor = UIColor.init(red: 238/255.0, green: 52/255.0, blue: 51/255.0, alpha: 1.0)
    public static let CELL_UPLOAD_BTN_BG_COLOR: UIColor = UIColor.init(red: 47/255.0, green: 172/255.0, blue: 255/255.0, alpha: 1.0)
    
    
}
