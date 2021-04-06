//
//  SelectMeasurementViewController+TableView.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit

fileprivate let kCellIdentifier = "defaultCell"

extension SelectMeasurementViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    //MARK:- UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dispMeasurementList.count
    }
    
    //MARK:- UITableViewDelegate
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifier, for: indexPath)
        let measurement = self.dispMeasurementList[indexPath.row]
        cell.textLabel?.text = "\(measurement.baseTime!.toString(format: Config.MEASUREMENT_BASETIME_STRING_FORMAT)) - \(measurement.duration.durationString)"
        cell.detailTextLabel?.text = "UUID:\(measurement.uuid.prefix(8))..."
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let measurement = self.dispMeasurementList[indexPath.row]
        print("Did selected measurement name: \(measurement.uuid)")
        self.app.targetMeasurement = measurement
        self.goToNextView()
    }
}
