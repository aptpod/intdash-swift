//
//  UInt64Extension.swift
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//
import Foundation

extension UInt64 {
    
    var dataSizeString: String {
        let dValue = Double(self) * 10
        if(dValue < 1024){
            return "\(self)Bytes"
        }else if(dValue < NSDecimalNumber.init(decimal: pow(1024, 2)).doubleValue*10){
            return "\(round(dValue/1000)/10)KB"
        }else if(dValue < NSDecimalNumber.init(decimal: pow(1024, 4)).doubleValue*10){
            return "\(round(dValue/NSDecimalNumber.init(decimal: pow(1000, 2)).doubleValue)/10)MB"
        }else if(dValue < NSDecimalNumber.init(decimal: pow(1024, 5)).doubleValue*10){
            return "\(round(dValue/NSDecimalNumber.init(decimal: pow(1000, 3)).doubleValue)/10)GB"
        }else if(dValue < NSDecimalNumber.init(decimal: pow(1024, 6)).doubleValue*10){
            return "\(round(dValue/NSDecimalNumber.init(decimal: pow(1000, 4)).doubleValue)/10)TB"
        }else{
            return "\(self)Bytes"
        }
    }
}
