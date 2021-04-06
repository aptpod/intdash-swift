//
//  UISearchBarExtension.swift
//
//  Created by Ueno Masamitsu on 2021/02/03.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit

extension UISearchBar {
    var textField: UITextField? {
        if #available(iOS 13.0, *) {
            return searchTextField
        } else {
            return value(forKey: "_searchField") as? UITextField
        }
    }
}
