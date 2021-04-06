//
//  FrameRateCalculator.swift
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation

public protocol FrameRateCalculatorDelegate: NSObjectProtocol {
    /// フレームレートの計算時のコールバック
    /// - parameter calculator: FrameRateCalculator
    /// - parameter fps: フレームレート
    /// 1秒ごとにフレームレートが出力される
    func didCalculateFrameRate(_ calculator: FrameRateCalculator, fps: Int)
}

///
/// フレームレート計算クラス
///
public class FrameRateCalculator {
    
    private var timer: Timer?
    private var fps: Int = 0
    private var cnt = 0

    /// FrameRateCalculatorDelegate
    public weak var delegate: FrameRateCalculatorDelegate?
    
    public init() {}
    
    /// タグ
    public var tag: Int = 0
    
    public func start() {
        self.reset()
        if(self.timer != nil){
            self.timer?.invalidate()
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
            self.fps = self.cnt
            self.cnt = 0
            self.delegate?.didCalculateFrameRate(self, fps: self.fps)
        }
    }
    
    public func reset() {
        self.cnt = 0
        self.fps = 0
    }
    
    public func stop(){
        self.timer?.invalidate()
        self.timer = nil
    }
    
    public func step() {
        self.cnt += 1
    }
    
    /// - returns: 現在のフレームレート値
    public func getFps() -> Int {
        return fps
    }
}
