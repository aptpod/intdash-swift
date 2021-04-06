//
//  DeviceListViewController.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth

class DeviceListViewController: UIViewController {
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate
    
    //MARK: Bluetooth
    var scanningDevices: [PeripheralDevice] = []
    var deviceListLock = NSLock()
    
    var selectedPeripheral: CBPeripheral!
    
    //MARK: TableView
    @IBOutlet weak var tableView: UITableView!
    
    var loadinAlertDialog: LoadingAlertDialogView?
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - DeviceListViewController")
        
        self.setupTableView()
        self.setupBLEManager()
        
        AlertDialogView.showAlert(viewController: self, message: "Select the device to be connected.")
    }
    
    //MARK:- viewDidAppear
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear - DeviceListViewController")
        self.app.bleManager.startScanning(services: [Config.TARGET_SERIVCE_UUID])
    }

    //MARK:- viewDidDisappear
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("viewDidDisappear - DeviceListViewController")
        self.app.bleManager.stopScanning()
    }
    
    func goToMainView(peripheral: CBPeripheral) {
        self.selectedPeripheral = peripheral
        let backButton = UIBarButtonItem()
        backButton.title = "Disconnect"
        self.navigationItem.backBarButtonItem = backButton
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: MainViewController.VIEW_IDENTIFIER) {
            if let vc = vc as? MainViewController {
                vc.targetPeripheral = self.selectedPeripheral
            }            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
}
