//
//  MySystemClock.swift
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation
import Intdash

// NTPおよび端末内のクロックを使用して時刻を調整するクラス
public class MySystemClock {
    
    static let shared = MySystemClock()
    private var tb = mach_timebase_info()
    
    // NTPManager
    let ntpManager = NTPManager()
    
    // RTC
    public private(set) var rtcBaseDate: Date
    public private(set) var rtcBaseValue: Double
    
    // 現在のRaw値を取得する
    public var nowValue: TimeInterval {
        mach_timebase_info(&tb)
        let tsc = mach_absolute_time()
        return Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
    }
    
    // 計測の基準時刻を取得する
    public var rtcDate: Date {
        // 計測に使う時刻は常に端末時刻に固定
        mach_timebase_info(&tb)
        let tsc = mach_absolute_time()
        let t = Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
        let interval = t - self.rtcBaseValue
        return Date.init(timeInterval: interval, since: self.rtcBaseDate)
    }
    
    // CPUベースの時計をリセットする
    public func resetRtc() {
        self.rtcBaseDate = Date()
        mach_timebase_info(&tb)
        let tsc = mach_absolute_time()
        self.rtcBaseValue = Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
        NSLog("resetRtc - MySystemClock")
    }
    
    // NTP
    public private(set) var ntpBaseDate: Date
    public private(set) var ntpBaseValue: Double
    
    private var ntpOffset: TimeInterval = 0 {
        didSet {
            self.ntpBaseDate = Date()
            mach_timebase_info(&tb)
            let tsc = mach_absolute_time()
            self.ntpBaseValue = Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
        }
    }
    
    // NTPベースで調整された時刻を取得する
    public var ntpDate: Date {
        mach_timebase_info(&tb)
        let tsc = mach_absolute_time()
        let t = Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
        let interval = t - (self.ntpBaseValue+self.ntpOffset)
        return Date.init(timeInterval: interval, since: self.ntpBaseDate)
    }
    
    private init() {
        let date = Date()
        mach_timebase_info(&tb)
        let tsc = mach_absolute_time()
        let t = Double(tsc) * Double(tb.numer) / Double(tb.denom) / 1000000000.0
        // RTC
        self.rtcBaseDate = date
        self.rtcBaseValue = t
        // NTP
        self.ntpBaseDate = date
        self.ntpBaseValue = t
        NSLog("init - MySystemClock")
    }
    
    public func updateNTPTime(completion: ((Error?)->())? = nil) {
        DispatchQueue.global().async {
            self.ntpManager.sync { [weak self] offset, error in
                if let error = error {
                    print("Failed to get offset between ntp and system clock. \(error)")
                    completion?(error)
                } else {
                    print("Update Offset between ntp and system clock:\(offset)")
                    self?.ntpOffset = -offset
                    completion?(nil)
                }
            }
        }
    }
}
