//
//  MainViewController+ViewEvents.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

fileprivate let kPortNumber = "portNumber"

extension MainViewController: UITextFieldDelegate {
    
    func setupViewEvents() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "YYYY/MM/dd HH:mm:ss.SSS"
        
        let port = self.getPortNumber()
        self.inputPortTextField.text = "\(port)"
        self.inputPortTextField.delegate = self
        
        self.enablePortSwitch.addTarget(self, action: #selector(enablePortSwitchValueChanged(_:)), for: .valueChanged)
        self.motionIconBtn.addTarget(self, action: #selector(motionIconBtnPushed(_:)), for: .touchUpInside)
    }
    
    @IBAction func motionIconBtnPushed(_ sender: Any) {
        print("motionIconBtnPushed")
        self.launchMotionApp()
    }
    
    func setEnableSwitchValue(isOn: Bool, animated: Bool = true) {
        self.enablePortSwitch.setOn(isOn, animated: animated)
        self.enablePortSwitchValueChanged(self.enablePortSwitch)
    }
    
    @IBAction func enablePortSwitchValueChanged(_ sender: UISwitch) {
        print("enablePortSwitchValueChanged isOn: \(sender.isOn)")
        if sender.isOn {
            self.startConnection()
        } else {
            self.stopConnection()
        }
    }
    
    func getPortNumber() -> Int {
        if let value = UserDefaults.standard.string(forKey: kPortNumber), let port = Int(value) { return port }
        return Config.PORT_NUMBER_DEFAULT
    }
    
    func setPortNumber(value: Int) {
        UserDefaults.standard.set(value, forKey: kPortNumber)
    }
    
    //MARK:- UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("textFieldDidBeginEditing")
        textField.resignFirstResponder()
        self.setEnableSwitchValue(isOn: false)
        let defaultText = self.inputPortTextField.text
        let alert = UIAlertController(title: "Please input the port number.", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = defaultText
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (action) in
            guard let textField = alert.textFields?.first else { return }
            guard let text = textField.text, !text.isEmpty else {
                self?.inputPortTextField.text = defaultText
                return
            }
            self?.inputPortTextField.text = text
            self?.setEnableSwitchValue(isOn: true)
        }))
        self.present(alert, animated: true, completion: nil)
    }
}
