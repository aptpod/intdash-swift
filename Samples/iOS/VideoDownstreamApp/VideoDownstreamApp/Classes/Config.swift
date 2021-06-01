//
//  Config.swift
//  VideoDownstreamSample
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
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
    static let INTDASH_LOG_LEVEL: IntdashLogLevel = .info
    static let INTDASH_TARGET_CHANNEL_DEFAULT: Int = 1
    
    // View Contents
    static let CURRENT_TIME_REFRESH_RATE: Int = 60
    static let CURRENT_TIME_FORMAT_STRING = "HH:mm:ss.SSS"
    static let CURRENT_TIME_DEFAULT_STRING = "00:00:00.000"
    static let BUTTON_ACTIVE_TEXT_COLOR: UIColor = UIColor.init(red: 215/255.0, green: 62/255.0, blue: 133/255.0, alpha: 1.0)
    static let BUTTON_DEACTIVE_TEXT_COLOR: UIColor = UIColor.white
    static let SEARCH_BAR_TEXT_COLOR: UIColor = UIColor.white
}
