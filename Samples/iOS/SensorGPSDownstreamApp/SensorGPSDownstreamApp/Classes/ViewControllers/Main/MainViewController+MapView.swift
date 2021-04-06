//
//  MainViewController+MapView.swift
//  SensorGPSDownstreamApp
//
//  Created by Ueno Masamitsu on 2020/09/23.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import MapKit

extension MainViewController: MKMapViewDelegate {
    
    func setupMapView() {
        self.mapView.delegate = self
        self.isUserTracking = true
        self.didUpdateUserTrackingFlag()
        self.mapViewInfoBtn.addTarget(self, action: #selector(mapViewInfoBtnPushed(_:)), for: .touchUpInside)
    }
    
    @IBAction func mapViewInfoBtnPushed(_ sender: Any) {
        self.isUserTracking = !self.isUserTracking
        print("mapViewInfoBtnPushed isUserTracking: \(self.isUserTracking)")
        if self.isUserTracking, self.userAnnotation != nil {
            let camera = self.mapView.camera
            if let head = self.lastHead {
                let camera = self.mapView.camera
                camera.heading = head
            }
            if let coordinate = self.lastLocation {
                camera.centerCoordinate = coordinate
            }
            self.mapView.setCamera(camera, animated: true)
        }
    }
    
    func didUpdateUserTrackingFlag() {
        if !self.isUserTracking {
            self.mapViewInfoBtn.tintColor = Config.MAP_VIEW_INFO_BTN_DEFAULT_COLOR
            self.mapViewInfoBtn.backgroundColor = Config.MAP_VIEW_INFO_BTN_DEFAULT_BG_COLOR
        } else {
            self.mapViewInfoBtn.tintColor = Config.MAP_VIEW_INFO_BTN_SELECTED_COLOR
            self.mapViewInfoBtn.backgroundColor = Config.MAP_VIEW_INFO_BTN_SELECTED_BG_COLOR
        }
    }
    
    func setUserLocation(latitude: Double, longitude: Double) {
        print("Did received user location latitude: \(latitude), longitude: \(longitude)")
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.lastLocation = coordinate
        if self.userAnnotation == nil {
            self.isUserTracking = true
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = self.app.targetEdge?.name
            self.userAnnotation = annotation
            DispatchQueue.main.async {
                self.mapView.addAnnotation(annotation)
                
                guard self.isUserTracking else { return }
                let camera = self.mapView.camera
                if #available(iOS 13.0, *) {
                    camera.centerCoordinateDistance = Config.MAP_VIEW_USER_MARKER_CAMERA_DEFAULT_DISTANCE
                } else {
                    camera.altitude = Config.MAP_VIEW_USER_MARKER_CAMERA_DEFAULT_DISTANCE
                }
                camera.centerCoordinate = coordinate
                self.mapView.setCamera(camera, animated: true)
            }
        } else {
            self.userAnnotation?.coordinate = coordinate
            guard self.isUserTracking else { return }
            let camera = self.mapView.camera
            camera.centerCoordinate = coordinate
            self.mapView.setCamera(camera, animated: true)
        }
    }
    
    func setUserHead(head: Double) {
        print("Did received user head: \(head)")
        self.lastHead = head
        guard self.userAnnotation != nil, self.isUserTracking else { return }
        DispatchQueue.main.async {
            let camera = self.mapView.camera
            camera.heading = head
            self.mapView.setCamera(camera, animated: true)
        }
    }
    
    //MARK:- MKMapViewDelegate
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier, for: annotation)
        if let markerAnnotationView = annotationView as? MKMarkerAnnotationView {
            markerAnnotationView.glyphTintColor = Config.MAP_VIEW_USER_MARKER_BALLOON_TEXT_TINT_COLOR
            markerAnnotationView.glyphText = Config.MAP_VIEW_USER_MARKER_BALLOON_TEXT
            markerAnnotationView.markerTintColor = Config.MAP_VIEW_USER_MARKER_BALLOON_TINT_COLOR
        }
        return annotationView
    }
}
