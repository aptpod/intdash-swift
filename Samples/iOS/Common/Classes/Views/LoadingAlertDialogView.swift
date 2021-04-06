//
//  LoadingAlertDialogView.swift
//
//  Created by Ueno Masamitsu on 2020/09/15.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

fileprivate let kLabelMarginY: CGFloat = 8

class LoadingAlertDialogView: NSObject {
    
    private var loadingView: UIView?
    private var indicatorView: UIActivityIndicatorView?
    private var messageLabel: UILabel?
    
    public init(addView: UIView) {
        super.init()
        self.loadingView = UIView.init(frame: addView.frame)
        self.loadingView?.backgroundColor = UIColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        self.loadingView?.translatesAutoresizingMaskIntoConstraints = false
        addView.addSubview(self.loadingView!)
        self.loadingView?.leadingAnchor.constraint(equalTo: addView.leadingAnchor, constant: 0).isActive = true
        self.loadingView?.trailingAnchor.constraint(equalTo: addView.trailingAnchor, constant: 0).isActive = true
        self.loadingView?.topAnchor.constraint(equalTo: addView.topAnchor, constant: 0).isActive = true
        self.loadingView?.bottomAnchor.constraint(equalTo: addView.bottomAnchor, constant: 0).isActive = true
        
        self.indicatorView = UIActivityIndicatorView.init(style: .whiteLarge)
        self.indicatorView?.color = UIColor.white
        self.indicatorView?.translatesAutoresizingMaskIntoConstraints = false
        self.loadingView?.addSubview(self.indicatorView!)
        self.indicatorView?.center = self.loadingView!.center
        self.indicatorView?.centerXAnchor.constraint(equalTo: loadingView!.centerXAnchor, constant: 0).isActive = true
        self.indicatorView?.centerYAnchor.constraint(equalTo: loadingView!.centerYAnchor, constant: 0).isActive = true
        
    }
    
    public init(addView: UIView, showMessageLabel: Bool) {
        super.init()
        self.loadingView = UIView.init(frame: addView.frame)
        self.loadingView?.backgroundColor = UIColor.init(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        self.loadingView?.translatesAutoresizingMaskIntoConstraints = false
        addView.addSubview(self.loadingView!)
        self.loadingView?.leadingAnchor.constraint(equalTo: addView.leadingAnchor, constant: 0).isActive = true
        self.loadingView?.trailingAnchor.constraint(equalTo: addView.trailingAnchor, constant: 0).isActive = true
        self.loadingView?.topAnchor.constraint(equalTo: addView.topAnchor, constant: 0).isActive = true
        self.loadingView?.bottomAnchor.constraint(equalTo: addView.bottomAnchor, constant: 0).isActive = true
        
        self.indicatorView = UIActivityIndicatorView.init(style: .whiteLarge)
        self.indicatorView?.color = UIColor.white
        self.indicatorView?.translatesAutoresizingMaskIntoConstraints = false
        self.loadingView?.addSubview(self.indicatorView!)
        self.indicatorView?.center = self.loadingView!.center
        self.indicatorView?.centerXAnchor.constraint(equalTo: loadingView!.centerXAnchor, constant: 0).isActive = true
        self.indicatorView?.centerYAnchor.constraint(equalTo: loadingView!.centerYAnchor, constant: 0).isActive = true
        
        if(showMessageLabel){
            self.messageLabel = UILabel.init()
            self.messageLabel?.textColor = UIColor.white
            self.messageLabel?.numberOfLines = 0
            self.messageLabel?.textAlignment = .center
            self.messageLabel?.translatesAutoresizingMaskIntoConstraints = false
            self.loadingView?.addSubview(self.messageLabel!)
            self.messageLabel?.center = self.loadingView!.center
            self.messageLabel?.centerXAnchor.constraint(equalTo: loadingView!.centerXAnchor, constant: 0).isActive = true
            self.messageLabel?.centerYAnchor.constraint(equalTo: loadingView!.centerYAnchor,
                                                         constant: self.indicatorView!.frame.size.height + kLabelMarginY).isActive = true
        }
    }
    
    public func setMessage(message: String) {
        self.messageLabel?.text = message
        self.messageLabel?.sizeToFit()
    }
    
    public func startAnimating() {
        self.indicatorView?.startAnimating()
    }
    
    public func stopAnimating() {
        self.indicatorView?.stopAnimating()
    }
    
    deinit {
        print("deinit - LoadingAlertDialogView")
        self.indicatorView?.stopAnimating()
        self.indicatorView?.removeFromSuperview()
        self.indicatorView = nil
        self.messageLabel?.removeFromSuperview()
        self.messageLabel = nil
        self.loadingView?.removeFromSuperview()
        self.loadingView = nil
    }
}

