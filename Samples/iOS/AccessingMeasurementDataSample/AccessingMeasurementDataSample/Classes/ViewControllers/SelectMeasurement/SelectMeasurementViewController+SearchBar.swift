//
//  SelectMeasurementViewController+SearchBar.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit

extension SelectMeasurementViewController: UISearchBarDelegate {
    
    func setupSearchBar() {
        if let textField = self.searchBar.textField {
            textField.textColor = Config.SEARCH_BAR_TEXT_COLOR
        }
        self.searchBar.delegate = self
    }
    
    func reloadMeasurementList(filterText: String? = nil) {
        var filterText = filterText
        self.reloadRequestFlag = true
        defer { self.listDataLock.unlock() }
        self.listDataLock.lock()
        self.reloadRequestFlag = false
        self.dispMeasurementList.removeAll()
        
        if filterText == nil {
            filterText = self.searchBar.text
        }
        
        let measurementList = self.measurementList
        for measurement in measurementList {
            if self.reloadRequestFlag { return }
            guard let filterText = filterText.toBlankEqualNull?.lowercased() else {
                self.dispMeasurementList.append(measurement)
                continue
            }
            if measurement.uuid.lowercased().contains(filterText) {
                self.dispMeasurementList.append(measurement)
                continue
            }
        }
        guard !self.reloadRequestFlag else { return }
        self.dispCntLabel.text = "\(self.dispMeasurementList.count)/\(measurementList.count)"
        self.tableView.reloadData()
    }
    
    //MARK:- UISearchBarDelegate
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("searchBarSearchButtonClicked - UISearchBarDelegate")
        searchBar.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print("searchBar textDidChange:\(searchText) - UISearchBarDelegate")
        self.reloadMeasurementList(filterText: searchText)
    }
}
