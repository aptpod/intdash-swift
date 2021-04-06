//
//  SelectEdgeViewController.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2020/09/24.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

fileprivate let kViewTitle = "Select Edge"

class SelectEdgeViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "selectEdgeView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var edgeCntLabel: UILabel!
    
    var edgeList: [EdgeItem] { self.app.edgeList }
    var dispEdgeList: [EdgeItem] = []
    
    var listDataLock = NSLock()
    var reloadRequestFlag: Bool = false
    
    // Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - SelectEdgeViewController")
        self.app.activeVC = self
        self.navigationItem.title = kViewTitle
        // SignOutBtn
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sign Out", style: .done, target: self, action: #selector(signOutBtnPushed(_:)))
        // SearchBar
        self.setupSearchBar()
        // TableView
        self.setupTableView()
    }
    
    @objc func signOutBtnPushed(_ sender: Any) {
        print("signOutBtnPushed")
        self.app.signOut()
    }
    
    func updateEdgeList() {
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async { [weak self] in
            defer { self?.listDataLock.unlock() }
            self?.listDataLock.lock()
            IntdashAPIManager.shared.requestEdgeList { [weak self] (response, error) in
                if let items = response?.items {
                    self?.app.edgeList = items
                }
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                    self?.reloadDispEdgeList(filterText: self?.searchBar.text)
                }
            }
        }
    }
    
    //MARK:- viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear - SelectEdgeViewController")
    }
    
    //MARK:- viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear - SelectEdgeViewController")
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - SelectEdgeViewController")
        self.updateEdgeList()
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - SelectEdgeViewController")
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - SelectEdgeViewController")
    }
    
    func goToNextView() {
        DispatchQueue.main.async {
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: SelectMeasurementViewController.VIEW_IDENTIFIER) {
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}
