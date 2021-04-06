//
//  SelectMeasurementViewController.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

fileprivate let kViewTitle = "Select Measurement"

class SelectMeasurementViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "selectMeasurementView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var dispCntLabel: UILabel!
    
    var measurementList: [MeasurementItem] = []
    var dispMeasurementList: [MeasurementItem] = []
    
    var listDataLock = NSLock()
    var reloadRequestFlag: Bool = false
    
    // Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - SelectMeasurementViewController")
        self.navigationItem.title = kViewTitle
        // SearchBar
        self.setupSearchBar()
        // TableView
        self.setupTableView()
    }
    
    func updateMeasurementList() {
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async { [weak self] in
            defer { self?.listDataLock.unlock() }
            self?.listDataLock.lock()
            let start = Date().timeIntervalSince1970 - Config.INTDASH_REQUEST_MEASUREMENT_LIST_DURATION
            let end = Date().timeIntervalSince1970
            // エッジ選択画面で選択されたエッジの計測を検索
            IntdashAPIManager.shared.requestMeasurementList(edgeUuid: self?.app.targetEdge?.uuid, start: start, end: end) { [weak self] (response, error) in
                if let response = response {
                    // 計測リストの中から、ベースタイムが取得でき、時間が1秒以上で、終了フラグがtrueのもののみを抽出
                    self?.measurementList = response.items.filter { $0.baseTime != nil && $0.duration >= 1 && $0.ended == true }
                }
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                    self?.reloadMeasurementList(filterText: self?.searchBar.text)
                }
            }
        }
    }
    
    //MARK:- viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear - SelectMeasurementViewController")
    }
    
    //MARK:- viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear - SelectMeasurementViewController")
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - SelectMeasurementViewController")
        self.updateMeasurementList()
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - SelectMeasurementViewController")
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - SelectMeasurementViewController")
    }
    
    func goToNextView() {
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                if let vc = self.storyboard?.instantiateViewController(withIdentifier: RequestDataPointsSampleViewController.VIEW_IDENTIFIER) {
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }
    }
}
