//
//  RequestDataPointsSampleViewController+TableView.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

fileprivate let kCellIdentifier = "defaultCell"

extension RequestDataPointsSampleViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    //MARK:- UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.dispCntLabel.text = "\(self.dataPointList.count) units"
        return self.dataPointList.count
    }
    
    //MARK:- UITableViewDelegate
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier, for: indexPath)
        let dataPoint = self.dataPointList[indexPath.row]
        let type = IntdashDataType.init(rawValue: dataPoint.dataType)
        cell.textLabel?.text = type != nil ? "\(type!) (\(dataPoint.dataType)) - (\(dataPoint.dataId))" : "Non supported data type (\(dataPoint.dataType))"
        cell.detailTextLabel?.text = dataPoint.time?.rfc3339String ?? "Not found"
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
