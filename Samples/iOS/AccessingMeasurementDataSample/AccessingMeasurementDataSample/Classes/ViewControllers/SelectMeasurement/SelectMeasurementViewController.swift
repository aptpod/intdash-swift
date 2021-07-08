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
        guard let uuid = self.app.targetEdge?.uuid else {
            print("Failed to get target uuid.")
            return
        }
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async { [weak self] in
            defer { self?.listDataLock.unlock() }
            self?.listDataLock.lock()
            let start = Date().timeIntervalSince1970 - Config.INTDASH_REQUEST_MEASUREMENT_LIST_DURATION
            let end = Date().timeIntervalSince1970
            self?.requestMeasurementList(edgeUuid: uuid, start: start, end: end)
        }
    }
    
    func requestMeasurementList(edgeUuid: String, start: TimeInterval, end: TimeInterval, page: Int = 1, items: [String: MeasurementItem] = [String: MeasurementItem]()) {
        var items = items
        // エッジ選択画面で選択されたエッジの計測を検索
        IntdashAPIManager.shared.requestMeasurementList(edgeUuid: edgeUuid, start: start, end: end, durationStart: Config.INTDASH_REQUEST_MEASUREMENT_DURATION_START, limit: Config.INTDASH_REQUEST_MEASUREMENT_LIMIT) { [weak self] (response, error) in
            if let response = response {
                for item in response.items {
                    items[item.uuid] = item
                }
            }
            // 次のページが存在しなければ要求終了
            guard response?.page?.last == false else {
                // 取得できた計測リストの中からベースタイムが取得でき、終了フラグがtrueの物のみを抽出
                self?.measurementList = items.values.filter { $0.baseTime != nil && $0.ended == true }.sorted(by: { (item1, item2) -> Bool in
                    let date1 = item1.createdAt
                    let date2 = item2.createdAt
                    return date1!.compare(date2!) == .orderedDescending
                })
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                    self?.reloadMeasurementList(filterText: self?.searchBar.text)
                }
                return
            }
            // 次のページが存在するので再度要求
            self?.requestMeasurementList(edgeUuid: edgeUuid, start: start, end: end, page: page+1, items: items)
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
