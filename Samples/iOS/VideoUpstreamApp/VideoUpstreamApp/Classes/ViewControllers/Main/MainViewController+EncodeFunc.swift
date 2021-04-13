//
//  MainViewController+EncodeFunc.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/23.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

extension MainViewController {
    
    func encodeImage(image: UIImage, timestamp: TimeInterval) {
        /// ToDo
        /// `IntdashMediaSDK` を利用するとH.264やH.265等のエンコードが行えます。
        guard let jpeg = image.jpegData(compressionQuality: Config.JPEG_COMPRESS_QUALITY) else {
            print("Failed to encode image.")
            return
        }
//        DispatchQueue.main.async {
//            // Decode Image Preview
//            if let decodeImage = UIImage.init(data: jpeg) {
//                self.previewImageView.image = decodeImage
//                self.resolutionLabel.text = String.init(format: "%.0fx%.0f", decodeImage.size.width, decodeImage.size.height)
//                self.timestampLabel.text = self.timestampFormat.string(from: Date(timeIntervalSince1970: timestamp))
//            }
//        }        
        self.sendJPEG(jpeg: jpeg, timestamp: timestamp)
    }
    
    func sendJPEG(jpeg: Data, timestamp: TimeInterval) {
        guard let streamId = self.upstreamId else { return }
        
        self.clockLock.lock()
        // 計測開始時間が未送信であれば送信します。
        if self.baseTime == -1 {
            self.sendFirstData(timestamp: timestamp)
        }
        self.clockLock.unlock()
        
        // 計測開始時間から経過時間を算出します。
        let elapsedTime = timestamp - self.baseTime
        guard elapsedTime >= 0 else {
            print("Elapsed time error. \(elapsedTime)")
            return
        }
        DispatchQueue.global().async {
            do {
                // 送信する`IntdashData`を生成します。
                let data = IntdashData.DataJPEG(data: [UInt8](jpeg))
                // データ送信前の保存処理。
                if let fileManager = self.intdashDataFileManager {
                    _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                }
                // 生成した`IntdashData`を送信します。
                try self.intdashClient?.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
            } catch {
                print("Failed to send jpeg. \(error)")
            }
        }
        
    }
}
