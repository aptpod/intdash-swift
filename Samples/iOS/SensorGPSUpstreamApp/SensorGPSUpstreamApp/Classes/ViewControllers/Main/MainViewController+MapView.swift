//
//  MainViewController+MapView.swift
//  SensorGPSUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import MapKit

fileprivate let kUserTrackingBtnBottomMargin: CGFloat = -8
fileprivate let kUserTrackingBtnRightMargin: CGFloat = -8

extension MainViewController: MKMapViewDelegate {
    
    func setupMapView() {
        self.mapView.delegate = self
        self.mapView.userTrackingMode = .followWithHeading
        self.mapView.showsUserLocation = true
        
        // User Tracking Btn
        self.userTrackingBtn = MKUserTrackingButton(mapView: self.mapView)
        self.userTrackingBtn.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.userTrackingBtn)
        
        self.userTrackingBtn.bottomAnchor.constraint(equalTo: self.streamControlBtn.topAnchor, constant: kUserTrackingBtnBottomMargin).isActive = true
        self.userTrackingBtn.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: kUserTrackingBtnRightMargin).isActive = true
    }
}
