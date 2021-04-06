//
//  AlertDialogView.swift
//
//  Created by Ueno Masamitsu on 2020/09/16.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit

class AlertDialogView {
    
    public static func showAlert(viewController: UIViewController, title: String?, message: String?, btnTitle: String, completion: (() -> ())?) {
        DispatchQueue.main.async {
            let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
            let btn = UIAlertAction.init(title: btnTitle, style: .default, handler: { (_) in
                completion?()
            })
            alert.addAction(btn)
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    public static func showAlert(viewController: UIViewController, title: String?, message: String?, positiveBtnTitle: String = "OK", negativeBtnTitle: String = "Cancel", boolCompletion: ((Bool) -> ())?) {
        DispatchQueue.main.async {
            let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: negativeBtnTitle, style: .cancel, handler: { (_) in
                boolCompletion?(false)
            }))
            alert.addAction(UIAlertAction.init(title: positiveBtnTitle, style: .default, handler: { (_) in
                boolCompletion?(true)
            }))
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    public static func showAlert(viewController: UIViewController, title: String?, message: String?, btnTitle: String) {
        showAlert(viewController: viewController, title: title, message: message, btnTitle: btnTitle, completion: nil)
    }
    
    public static func showAlert(viewController: UIViewController, message: String?) {
        showAlert(viewController: viewController, title: nil, message: message, btnTitle: "OK")
    }
    
    public static func showAlert(viewController: UIViewController, title: String?, message: String?, completion: (() -> ())?) {
        showAlert(viewController: viewController, title: title, message: message, btnTitle: "OK", completion: completion)
    }
    
    public static func showAlert(viewController: UIViewController, message: String?, btnTitle: String, completion: (() -> ())?) {
        showAlert(viewController: viewController, title: nil, message: message, btnTitle: btnTitle,completion: completion)
    }
    
    public static func showAlert(viewController: UIViewController, message: String?, completion: (() -> ())?) {
        showAlert(viewController: viewController, title: nil, message: message, btnTitle: "OK", completion: completion)
    }
    
    public static func showAlert(viewController: UIViewController, title: String?, message: String?) {
        showAlert(viewController: viewController, title: title, message: message, btnTitle: "OK")
    }
    
    public static func showAlert(viewController: UIViewController, message: String?, btnTitle: String) {
        showAlert(viewController: viewController, title: nil, message: message, btnTitle: btnTitle)
    }
    
}

