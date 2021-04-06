//
//  DateExtension.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import Foundation

extension Date {
    func addDay(day: Int) -> Date? {
        let calendar = NSCalendar(identifier: .ISO8601)
        var dateComponents = calendar?.components(in: .current, from: self)
        dateComponents!.day! += day
        return dateComponents!.date
    }
    
    func addHour(hour: Int) -> Date? {
        let calendar = NSCalendar(identifier: .ISO8601)
        var dateComponents = calendar?.components(in: .current, from: self)
        dateComponents!.hour! += hour
        return dateComponents!.date
    }
    
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
