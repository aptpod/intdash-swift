//
//  CMSampleBufferExtension.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import AVFoundation

extension CMSampleBuffer {
    public func toUIImage() -> UIImage? {
        guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        
        let ciImage = CIImage.init(cvPixelBuffer: imageBuffer)
        return UIImage.init(ciImage: ciImage)
    }
}
