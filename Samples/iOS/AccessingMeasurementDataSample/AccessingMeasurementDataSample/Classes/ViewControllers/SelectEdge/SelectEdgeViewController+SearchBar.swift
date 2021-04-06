//
//  SelectEdgeViewController+ViewEvents.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2020/09/24.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension SelectEdgeViewController: UISearchBarDelegate {
    
    func setupSearchBar() {
        self.searchBar.text = IntdashAPIManager.shared.signInEdgeName
        if let textField = self.searchBar.textField {
            textField.textColor = Config.SEARCH_BAR_TEXT_COLOR
        }
        self.searchBar.delegate = self
    }
    
    func reloadDispEdgeList(filterText: String? = nil) {
        var filterText = filterText
        self.reloadRequestFlag = true
        defer { self.listDataLock.unlock() }
        self.listDataLock.lock()
        self.reloadRequestFlag = false
        self.dispEdgeList.removeAll()
        
        if filterText == nil {
            filterText = self.searchBar.text
        }
        
        let edgeList = self.edgeList
        for edge in edgeList {
            if self.reloadRequestFlag { return }
            guard let filterText = filterText.toBlankEqualNull?.lowercased() else {
                self.dispEdgeList.append(edge)
                continue
            }
            if edge.name.lowercased().contains(filterText) {
                self.dispEdgeList.append(edge)
                continue
            }
        }
        guard !self.reloadRequestFlag else { return }
        self.edgeCntLabel.text = "\(self.dispEdgeList.count)/\(edgeList.count)"
        self.tableView.reloadData()
    }
    
    //MARK:- UISearchBarDelegate
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("searchBarSearchButtonClicked - UISearchBarDelegate")
        searchBar.endEditing(true)        
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print("searchBar textDidChange:\(searchText) - UISearchBarDelegate")
        self.reloadDispEdgeList(filterText: searchText)
    }
}
