//
//  TimeIntervalExtension.swift
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation

extension TimeInterval {
    
    var timeString: String {
        let t = Int(self)
        let h = t / 3600 % 24
        let m = t / 60 % 60
        let s = t % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    var durationString: String {
        let t = Int(self)
        let h = t / 3600 % 24
        let m = t / 60 % 60
        let s = t % 60
        var str = ""
        if h > 0 { str.append(String(format: "%02dh ", h)) }
        if m > 0 { str.append(String(format: "%02dm ", m)) }
        str.append(String(format: "%ds", s))
        return str
    }
}
