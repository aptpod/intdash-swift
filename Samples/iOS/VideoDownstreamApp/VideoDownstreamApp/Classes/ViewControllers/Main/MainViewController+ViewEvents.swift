//
//  MainViewController+ViewEvents.swift
//  VideoDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func setupViewEvents() {
        self.streamControlBtn.addTarget(self, action: #selector(streamControlBtnPushed(_:)), for: .touchUpInside)
        self.currentTimeFormat = DateFormatter()
        self.currentTimeFormat.dateFormat = Config.CURRENT_TIME_FORMAT_STRING
    }
    
    @IBAction func streamControlBtnPushed(_ sender: Any) {
        print("streamControlBtnPushed")
        self.startStream()
    }
    
    func updateStreamControlBtn() {
        DispatchQueue.main.async {
            if self.intdashClient != nil {
                self.streamControlBtn.setTitle("STOP DOWNSTREAM", for: .normal)
                self.streamControlBtn.setTitleColor(Config.BUTTON_ACTIVE_TEXT_COLOR, for: .normal)
                self.startCurrentTimeCheckTimer()
            } else {
                self.streamControlBtn.setTitle("START DOWNSTREAM", for: .normal)
                self.streamControlBtn.setTitleColor(Config.BUTTON_DEACTIVE_TEXT_COLOR, for: .normal)
                self.stopCurrentTimeCheckTimer()
            }
        }
    }
    
    func startCurrentTimeCheckTimer() {
        guard self.displayLink == nil else { return }
        self.displayLink = CADisplayLink(target: self, selector: #selector(willRefreshDisplay(_:)))
        self.displayLink?.preferredFramesPerSecond = Config.CURRENT_TIME_REFRESH_RATE
        self.displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc func willRefreshDisplay(_ displayLink: CADisplayLink) {
        let now = Date()
        self.currentTimeLabel.text = self.currentTimeFormat.string(from: now)
    }
    
    func stopCurrentTimeCheckTimer() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}
