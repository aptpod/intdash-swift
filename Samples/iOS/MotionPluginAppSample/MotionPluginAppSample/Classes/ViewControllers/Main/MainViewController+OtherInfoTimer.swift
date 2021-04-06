//
//  MainViewController+Backend.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/10/05.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Foundation

fileprivate let kSendNameInterval: TimeInterval = 10

extension MainViewController {
    
    func startOtherInfoTimer() {
        /// ToDo
        /// 定期的にプラグイン名を送る
        self.sendNameTimer = Timer.scheduledTimer(withTimeInterval: kSendNameInterval, repeats: true, block: { [weak self] (_) in
            self?.sendName()
        })
    }
    
    func stopOtherInfoTimer() {
        self.sendNameTimer?.invalidate()
        self.sendNameTimer = nil
    }
    
    func sendName() {
        let strs = NSMutableString()
        strs.append("{")
        strs.append("\n  \"name\": \"\(Config.PLUGIN_APP_NAME)\"")
        strs.append("\n}")
        let message = String(strs)
        guard let messageData = message.data(using: .utf8) else { return }
        self.sendMessage(data: messageData)
    }
}
