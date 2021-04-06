//
//  MainViewController+CaptureDeviceFunc.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import AVFoundation



extension MainViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func startCapturing() {
        do {
            guard let device = AVCaptureDevice.default(Config.CAMERA_DEVICE_TYPE, for: .video, position: Config.CAMERA_CAPTURE_POSITION) else {
                print("Not found capture device.")
                throw NSError.init(domain: "Not found capture device.", code: -1, userInfo: nil)
            }
            
            let input = try AVCaptureDeviceInput.init(device: device)
            let output = AVCaptureVideoDataOutput()
            
            // When the queue is blocked and a new frame comes in, delete it.
            output.alwaysDiscardsLateVideoFrames = true
            
            // Pixel Format
            let pixelFormat: Dictionary = [kCVPixelBufferPixelFormatTypeKey as String: Config.CAMERA_PIXEL_FORMAT_TYPE]
            output.videoSettings = pixelFormat
            
            let session = AVCaptureSession()
            // ToDo
            // Setting the output resolution, frame rate, shutter speed, focus mode...
            session.sessionPreset = Config.CAMERA_CAPTURE_PRESET
            
            guard session.canAddInput(input) else { throw NSError.init(domain: "Failed to add input source.", code: -1, userInfo: nil) }
            session.addInput(input)
            
            guard session.canAddOutput(output) else { throw NSError.init(domain: "Failed to add output destination", code: -1, userInfo: nil) }
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: .global())
            
            for connection in output.connections {
                for port in connection.inputPorts {
                    if(port.mediaType == .video){
                        self.captureConnection = connection
                    }
                }
            }
            
            self.captureDevice = device
            self.captureSession = session
            
            // Update output orientation.
            self.updateCaptureOrientation()
            
            // Start capturing.
            session.startRunning()
        } catch {
            print("Failed to start capture.")
            AlertDialogView.showAlert(viewController: self, message: error.localizedDescription)
            return
        }
    }
    
    func updateCaptureOrientation() {
        guard let session = self.captureSession, let connection = self.captureConnection else { return }
        session.beginConfiguration()
        switch self.view.interfaceOrientation {
        case .landscapeLeft:
            connection.videoOrientation = .landscapeLeft
            break
        case .landscapeRight:
            connection.videoOrientation = .landscapeRight
            break
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
            break
        default:
            connection.videoOrientation = .portrait
            break
        }
        session.commitConfiguration()
    }
    
    func stopCapturing() {
        guard let session = self.captureSession else { return }
        self.captureSession = nil
        // Stop capture.
        session.stopRunning()
    }
    
    //MARK:- AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let rtcTime = MySystemClock.shared.rtcDate.timeIntervalSince1970
        NSLog("captureOutput sampleBuffer.")
        guard let image = sampleBuffer.toUIImage() else { return }
        // Original Image Preview
        DispatchQueue.main.async {
            self.previewImageView.image = image
            self.resolutionLabel.text = String.init(format: "%.0fx%.0f", image.size.width, image.size.height)
            self.timestampLabel.text = self.timestampFormat.string(from: Date(timeIntervalSince1970: rtcTime))
        }
        DispatchQueue.global().async {
            self.encodeImage(image: image, timestamp: rtcTime)
        }
    }
}
