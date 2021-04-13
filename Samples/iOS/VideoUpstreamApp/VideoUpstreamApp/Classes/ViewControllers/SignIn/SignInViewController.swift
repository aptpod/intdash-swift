//
//  SignInViewController.swift
//  VideoUpstreamApp
//
//  Created by Ueno Masamitsu on 2020/10/22.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import Intdash

class SignInViewController: UIViewController, IntdashSignInViewDelegate {
    
    // App Delegate
    let app: AppDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var signInView: IntdashSignInView!
    
    //MARK:- viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        print("viewDidLoad - SignInViewController")
        self.signInView.callbackURLScheme = Config.CALLBACK_URL_SCHEME
        self.signInView.delegate = self
    }
    
    //MARK:- deinit
    deinit {
        print("deinit - SignInViewController")
    }
    
    func goToNextView() {
        DispatchQueue.main.async {
           if let vc = self.storyboard?.instantiateViewController(withIdentifier: MainViewController.VIEW_IDENTIFIER) {
                let nc = UINavigationController(rootViewController: vc)
                nc.navigationBar.barStyle = self.navigationController!.navigationBar.barStyle
                nc.modalPresentationStyle = .fullScreen
                self.navigationController?.present(nc, animated: true, completion: nil)
           }
        }
    }
    
    //MARK:-  Loading Dialog
    var loadingDialog: LoadingAlertDialogView?
    func startLoading() {
        guard self.loadingDialog == nil else { return }
        DispatchQueue.main.async {
            self.loadingDialog = LoadingAlertDialogView.init(addView: self.app.window!, showMessageLabel: false)
            self.loadingDialog?.startAnimating()
        }
    }
    func stopLoading() {
        guard self.loadingDialog != nil else { return }
        DispatchQueue.main.async {
            self.loadingDialog?.stopAnimating()
            self.loadingDialog = nil
        }
    }

    //MARK:- IntdashSignInViewDelegate
    func didStartFetchToken(_ view: IntdashSignInView) {
        self.startLoading()
    }
    
    func didFinishFetchToken(_ view: IntdashSignInView, result: Bool, error: Error?) {
        print("didFinishFetchToken result: \(result), error: \(error?.localizedDescription ?? "nil") - IntdashSignInViewDelegate")
        self.stopLoading()
        // ToDo: 下部をコメントアウトすることで認証情報を用意していない場合でも次の画面を確認できます
        //guard result else { return }
        self.goToNextView()
    }
}

