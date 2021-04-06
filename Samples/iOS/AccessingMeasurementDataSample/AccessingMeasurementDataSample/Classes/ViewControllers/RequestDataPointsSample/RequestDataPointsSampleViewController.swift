//
//  RequestDataPointsSampleViewController.swift
//  AccessingMeasurementDataSample
//
//  Created by Ueno Masamitsu on 2021/02/05.
//  Copyright © 2021 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

fileprivate let kViewTitle = "Data Points"

class RequestDataPointsSampleViewController: UIViewController {
    
    static let VIEW_IDENTIFIER = "requestDataPointsSampleView"
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var dispCntLabel: UILabel!    
    
    var dataPointList: [DataPoint] = []
    
    var listDataLock = NSLock()
    var reloadRequestFlag: Bool = false
    
    // Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    
    var baseTime: TimeInterval!
    var elapsedTime: TimeInterval = 0
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - RequestDataPointsSampleViewController")
        self.navigationItem.title = kViewTitle
        // TableView
        self.setupTableView()
        guard self.app.targetMeasurement != nil else {
            print("Failed to get target measurement.")
            return
        }
        // BaseTime
        self.baseTime = self.app.targetMeasurement!.baseTime!.timeIntervalSince1970
    }
    
    @IBAction func resetBtnPushed(_ sender: Any) {
        print("resetBtnPushed")
        self.updateDataPoints(elapsedTime: 0)
    }
    
    @IBAction func nextBtnPushed(_ sender: Any) {
        print("nextBtnPushed")
        self.updateDataPoints(elapsedTime: self.elapsedTime)
    }
    
    func updateDataPoints(elapsedTime: TimeInterval) {
        guard let targetMeasurement = self.app.targetMeasurement else {
            print("Failed to get target measurement.")
            return
        }        
        let start = self.baseTime + elapsedTime
        let end = baseTime + targetMeasurement.duration
        guard start < end else {
            self.dataPointList = []
            self.tableView.reloadData()
            return
        }
        // 要求するデータのフィルターを作成する
        let filter = makeRequestDataPointsFilters()
        self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
        self.loadingDialog?.startAnimating()
        DispatchQueue.global().async { [weak self] in
            /// 1回のリクエストでは取得できない多数のデータポイントを取得する方法2種
            /// A: 時間範囲の起点（start）と終点（end）を指定し、
            ///    1回のリクエストで取得するデータポイント数(limit)を設定してリクエストする(このサンプルで行っている方法)。
            ///    レスポンスとしてデータポイントのリストを得たら、次のリクエストで、
            ///    「前のリクエストで取得したデータポイントの中で最大の経過時間（最も遅い時刻を持つデータポイントの経過時間）+
            ///    マージン(このサンプルではConfig.INTDASH_REQUEST_DATA_POINTS_NEXT_POINT_INTERVAL)」を、
            ///    起点（start）として指定し、リストの続きを取得する。
            ///    レスポンスに含まれるデータポイントが0個になるまでこれを繰り返す。
            ///
            /// B: 1回のリクエストで取得するデータポイント数は制限せず、一定の時間範囲（例：10秒間。ただしマージンを減算）を指定してリクエストする。
            ///    レスポンスとしてデータポイントのリストを得たら、次のリクエストで、リストの続き（次の10秒間に含まれるデータポイント）を取得する。
            ///    必要なだけこれを繰り返す。
            ///    例) 10秒間ずつデータポイントを取得する場合の例
            ///    let kRequestDuration: TimeInterval = 10
            ///    startTime = baseTime + elapsedTime
            ///    endTime = startTime + kRequestDuration - Config.INTDASH_REQUEST_DATA_POINTS_NEXT_POINT_INTERVAL
            ///    // Request...
            ///    elapsedTime += kRequestDuration
            ///    // 次のデータを取得
            ///    
            IntdashAPIManager.shared.requestDataPoints(name: targetMeasurement.uuid, filters: filter, start: start, end: end, limit: Config.INTDASH_REQUEST_DATA_POINTS_LIMIT) { (response, error) in
                var timestamp: TimeInterval = 0
                var date: Date?
                if let response = response {
                    print("Data points size: \(response.dataPoints.count)")
                    self?.dataPointList = response.dataPoints.sorted {
                        let t0 = $0.time?.timeIntervalSince1970
                        let t1 = $1.time?.timeIntervalSince1970
                        if t0 == nil, t1 == nil { return false }
                        else if t0 == nil || t1 == nil { return true }
                        return t0! < t1!
                    }
                    // データの最終経過時間を取得
                    for point in response.dataPoints {
                        if let t = point.time?.timeIntervalSince1970 {
                            if timestamp < t {
                                timestamp = t
                                date = point.time
                            }
                        }
                    }
                    if timestamp > 0 {
                        // 同じデータを要求しないように経過時間に最小時間を追加する
                        self?.elapsedTime = (timestamp - self!.baseTime) + Config.INTDASH_REQUEST_DATA_POINTS_NEXT_POINT_INTERVAL
                        print("timestamp: \(timestamp), elapsedTime: \(self!.elapsedTime), \(self!.elapsedTime + self!.baseTime), \(date?.rfc3339String ?? "")")
                    }
                }
                DispatchQueue.main.async {
                    self?.loadingDialog?.stopAnimating()
                    self?.loadingDialog = nil
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    func makeRequestDataPointsFilters() -> IntdashClient.DataPointsAPI.RequestFilters {
        // リクエストするデータポイントのフィルターを作成する
        let filters = IntdashClient.DataPointsAPI.RequestFilters()
        // 何も指定しない場合は全チャンネル、全データを取得されます
        // IDは数値または文字列で指定する
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.acceleration.rawValue)
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.gravity.rawValue)
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.rotationRate.rawValue)
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.orientationAngle.rawValue)
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.geoLocationCoordinate.rawValue)
//        filters.append(dataType: .generalSensor, channelNum: self.app.targetChannel, id: IntdashData.DataGeneralSensor.SensorId.geoLocationHeading.rawValue)
//        filters.append(dataType: .jpeg, channelNum: self.app.targetChannel, id: nil)
//        filters.append(dataType: .float, channelNum: self.app.targetChannel, ids: ["lat", "lng", "head"])
        return filters
    }
    
    //MARK:- viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear - RequestDataPointsSampleViewController")
    }
    
    //MARK:- viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("viewWillDisappear - RequestDataPointsSampleViewController")
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - RequestDataPointsSampleViewController")
        self.updateDataPoints(elapsedTime: 0)
    }
    
    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewWillDisappear - RequestDataPointsSampleViewController")
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - RequestDataPointsSampleViewController")
    }
}
