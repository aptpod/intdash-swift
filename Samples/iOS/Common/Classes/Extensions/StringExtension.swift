//
//  StringExtension.swift
//
//  Created by Ueno Masamitsu on 2020/09/24.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension String {
    
    var toBlankEqualNull: String? {
        guard !self.isEmpty else { return nil }
        return self
    }
    
    var localizedString: String {
        return NSLocalizedString(self, comment: "")
    }
}

extension Optional where Wrapped == String {
    
    var toBlankEqualNull: String? {
        guard let str = self else { return nil }
        guard !str.isEmpty else { return nil }
        return str
    }
    
}
