//
//  FileListViewController+ViewEvents.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

extension FileListViewController {
    
    func setupViewEvents() {
        let clearBtn = UIBarButtonItem.init(title: "Clear", style: .plain, target: self, action: #selector(clearBtnPushed(_:)))
        self.navigationItem.setRightBarButton(clearBtn, animated: true)
    }
    
    @IBAction func clearBtnPushed(_ sender: Any){
        print("clearBtnPushed")
        AlertDialogView.showAlert(viewController: self, title: "Check", message: "Delete all the files?") { (result) in
            print("Check to clear file list result: \(result)")
            if result {
                self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: true)
                self.loadingDialog?.startAnimating()
                DispatchQueue.global().async { [weak self] in
                    let fm = FileManager.default
                    if let edges = try? fm.contentsOfDirectory(atPath: Config.INTDASH_DATA_FILE_PARENT_PATH) {
                        print("Remove edge size: \(edges.count)")
                        edges.forEach { edgeUUID in
                            if let contents = try? fm.contentsOfDirectory(atPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)") {
                                print("Remove [\(edgeUUID)] contents size: \(contents.count)")
                                DispatchQueue.main.async {
                                    self?.loadingDialog?.setMessage(message: "0/\(contents.count)")
                                }
                                for i in 0..<contents.count {
                                    let measId = contents[i]
                                    print("Remove[\(i)]: \(measId)")
                                    try? fm.removeItem(atPath: "\(Config.INTDASH_DATA_FILE_PARENT_PATH)/\(edgeUUID)/\(measId)")
                                    DispatchQueue.main.async {
                                        self?.loadingDialog?.setMessage(message: "\(i+1)/\(contents.count)")
                                    }
                                }
                                self?.measDataList.removeAll()
                            }
                            DispatchQueue.main.async {
                                self?.loadingDialog?.stopAnimating()
                                self?.loadingDialog = nil
                                self?.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
    }
}
