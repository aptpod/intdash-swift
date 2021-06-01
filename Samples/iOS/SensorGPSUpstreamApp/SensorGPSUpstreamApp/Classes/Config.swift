//
//  Config.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/15.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion
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
    // If you want to save the data to the server, you must turn on this flag.
    public static let INTDASH_IS_SAVE_TO_SERVER = true
    public static let INTDASH_WAIT_FOR_SEND_UNITS_INTERVAL: TimeInterval = 0.001
    public static let INTDASH_UNITS_RESEND_TIME_INTERVAL: Int = 5
    
    // Intdash Data File Manager
    public static let INTDASH_DATA_FILE_PARENT_PATH = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    
    // The number of seconds to refresh the socket when data is stuck.
    public static let BADNETWORK_REFRESH_TIME: Int = 10
    
    // GPS Manager
    public static let GPS_INTDASH_TARGET_CHANNEL: Int = 1
    public static let GPS_LOCATION_ACCURACY: CLLocationAccuracy = kCLLocationAccuracyBest
    public static let GPS_IS_PRIMITIVE_DATA = false
    public static let GPS_PRIMITIVE_DATA_LATITUDE_ID: String = "lat"
    public static let GPS_PRIMITIVE_DATA_LONGITUDE_ID: String = "lng"
    public static let GPS_PRIMITIVE_DATA_HEAD_ID: String = "head"

    // Sensor Manager
    public static let SENSOR_INTDASH_TARGET_CHANNEL: Int = 1
    public static let SENSOR_USING_TYPE: CMAttitudeReferenceFrame = .xMagneticNorthZVertical
    public static let SENSOR_SAMPLING_RATE: Int = 50
    public static let SENSOR_IS_ENABLED_ACCELERATION = true
    public static let SENSOR_IS_ENABLED_GRAVITY_ACCELERATION = true
    public static let SENSOR_IS_ENABLED_ROTATION_RATE = true
    public static let SENSOR_IS_ENABLED_ORIENTATION_ANGLE = true
    public static var SENSOR_IS_UPSTREAM: Bool = SENSOR_IS_ENABLED_ACCELERATION || SENSOR_IS_ENABLED_GRAVITY_ACCELERATION || SENSOR_IS_ENABLED_ROTATION_RATE || SENSOR_IS_ENABLED_ORIENTATION_ANGLE
    
    // View Events
    static let CURRENT_TIME_REFRESH_RATE: Int = 2
    
    static let BUTTON_ACTIVE_TEXT_COLOR: UIColor = UIColor.init(red: 215/255.0, green: 62/255.0, blue: 133/255.0, alpha: 1.0)
    static let BUTTON_DEACTIVE_TEXT_COLOR: UIColor = UIColor.white
    
    // File List
    public static let CELL_DELETE_BTN_BG_COLOR: UIColor = UIColor.init(red: 238/255.0, green: 52/255.0, blue: 51/255.0, alpha: 1.0)
    public static let CELL_UPLOAD_BTN_BG_COLOR: UIColor = UIColor.init(red: 47/255.0, green: 172/255.0, blue: 255/255.0, alpha: 1.0)
    
    
}
