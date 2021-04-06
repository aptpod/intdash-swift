//
//  MainViewController+DecodeFunc.swift
//  VideoDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/23.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension MainViewController {
    
    func decodeJpeg(jpeg: Data, timestamp: TimeInterval) {
        guard let image = UIImage.init(data: jpeg) else {
            print("Failed to decode image.")
            return
        }
        DispatchQueue.main.async {
            // Preview Image
            self.previewImageView.image = image
            self.resolutionLabel.text = String.init(format: "%.0fx%.0f", image.size.width, image.size.height)
            self.timestampLabel.text = self.currentTimeFormat.string(from: Date(timeIntervalSince1970: timestamp))
        }
    }
}
