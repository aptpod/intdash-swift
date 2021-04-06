//
//  UIInterfaceOrientationExtension.swift
//
//  Created by Ueno Masamitsu on 2020/09/18.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension UIInterfaceOrientation {
    
    var name: String {
        switch self {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        default: return "unknown"
        }
    }
}
