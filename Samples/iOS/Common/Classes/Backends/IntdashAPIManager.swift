//
//  IntdashAPIManager.swift
//
//  Created by Ueno Masamitsu on 2020/09/11.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import Intdash
import UIKit

class IntdashAPIManager {
    
    fileprivate enum SessionInfo: String {
        case accessToken = "IntdashAPIManager-accessToken"
        case refreshToken = "IntdashAPIManager-refreshToken"
        case expiresIn = "IntdashAPIManager-expiresIn"
        case refreshTokenExpiresIn = "IntdashAPIManager-refreshTokenExpiresIn"
        case acquiredTime = "IntdashAPIManager-acquiredTime"
        case uuid = "IntdashAPIManager-uuid"
        case username = "IntdashAPIManager-username"
    }
    
    /// アクセストークンの有効期限が切れたときの通知
    static public let didDetectTokenExpired = NSNotification.Name("IntdashAPIManager-didDetectTokenExpired")
    
    static let shared = IntdashAPIManager()
    
    /// クライアントID
    private let clientId = kIntdashClientId
    
    var serverURL: String = kTargetServer {
        didSet {
            session?.serverURL = serverURL
        }
    }
    
    private(set) var session: IntdashClient.Session!
    
    private(set) var signInEdgeName: String?
    private(set) var singInEdgeUuid: String?

    private init() {
        setup()
    }
    
    public init(serverURL: String) {
        self.serverURL = serverURL
        setup()
    }
    
    private func setup() {
        session = IntdashClient.Session(serverURL: serverURL, clientId: clientId)
        restore()
        // IntdashClient.SessionはiOSの場合自動でアクセストークンのリフレッシュを行う
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidRefreshToken(_:)), name: IntdashClient.Session.didRefreshToken, object: nil)
        // トークンの状態をチェックする
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func sessionDidRefreshToken(_ notification: Notification) {
        print("sessionDidRefreshToken - IntdashAPIManager")
        save()
    }
    
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        print("applicationDidBecomeActive - IntdashAPIManager")
        // トークンが有効期限切れか？
        if !session.isRefreshable {
            // 通知
            NotificationCenter.default.post(name: IntdashAPIManager.didDetectTokenExpired, object: nil)
        }
    }
    
    /// サインアウトする
    public func signOut() {
        session.clearSession()
        clear()
        session = IntdashClient.Session(serverURL: serverURL, clientId: clientId)
    }
    
    func save() {
        let ud = UserDefaults.standard
        ud.set(session.accessToken, forKey: SessionInfo.accessToken.rawValue)
        ud.set(session.refreshToken, forKey: SessionInfo.refreshToken.rawValue)
        ud.set(session.expiresIn, forKey: SessionInfo.expiresIn.rawValue)
        ud.set(session.refreshTokenExpiresIn, forKey: SessionInfo.refreshTokenExpiresIn.rawValue)
        ud.set(session.acquiredTime, forKey: SessionInfo.acquiredTime.rawValue)
    }
    
    func restore() {
        let ud = UserDefaults.standard
        session.accessToken = ud.string(forKey: SessionInfo.accessToken.rawValue)
        session.refreshToken = ud.string(forKey: SessionInfo.refreshToken.rawValue)
        session.expiresIn = ud.double(forKey: SessionInfo.expiresIn.rawValue)
        session.refreshTokenExpiresIn = ud.double(forKey: SessionInfo.refreshTokenExpiresIn.rawValue)
        session.acquiredTime = ud.object(forKey: SessionInfo.acquiredTime.rawValue) as? Date
    }
    
    func clear() {
        let ud = UserDefaults.standard
        ud.set(nil, forKey: SessionInfo.accessToken.rawValue)
        ud.set(nil, forKey: SessionInfo.refreshToken.rawValue)
        ud.set(nil, forKey: SessionInfo.expiresIn.rawValue)
        ud.set(nil, forKey: SessionInfo.refreshTokenExpiresIn.rawValue)
        ud.set(nil, forKey: SessionInfo.acquiredTime.rawValue)
    }

    //MARK:- OAuth2
    /// 外部認証を行うURLを生成します。
    /// - parameter callbackURLScheme: リダイレクトURI(コールバックスキーマ)
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter url: 外部認証用のURL
    /// - parameter codeVerifier: 生成された検証コード
    /// - parameter state: CSRF対策の状態コード
    /// - parameter error: エラー情報
    func generateAuthorizationURL(callbackURLScheme: String, completion: @escaping (_ url: String?, _ codeVerifier: String?, _ state: String?, _ error: RESTError?)->()) {
        let api = IntdashClient.OAuth2API(session: session)
        api.generateAuthorizationURL(callbackURLScheme: callbackURLScheme, completion: completion)
    }
    
    /// 外部認証で取得した認証コードを使用してアクセストークンを取得します。
    /// 認証に成功すると、セッション情報にアクセストークンがセットされます。
    /// - parameter code: 外部認証で取得した認証コード
    /// - parameter codeVerifier: 生成された検証コード
    ///   `generateAuthorizationURL(callbackURLScheme:completion:)` のコールバックで返却される `codeVerifier` を使用してください。
    /// - parameter callbackURLScheme: リダイレクトURI(コールバックスキーマ)
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestAccessToken(code: String, codeVerifier: String, callbackURLScheme: String, completion: @escaping (_ date: Date?, _ error: RESTError?)->()) {
        let api = IntdashClient.OAuth2API(session: session)
        api.authenticate(code: code, codeVerifier: codeVerifier, callbackURLScheme: callbackURLScheme) { [weak self] (response, error) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let response = response else {
                completion(nil, nil)
                return
            }
            self?.save()
            print("succeeded to obtainToken. token: \(response.accessToken),"
                + "expires in: \(response.expiresIn)")
            completion(Date(timeInterval: TimeInterval(response.expiresIn), since: response.acquiredTime), nil)
        }
    }
    
    /// アクセストークンを更新する
    /// - parameter completion: 処理終了時のコールバック`(date, error)->()`, `date`: アクセストークンが失効する日時, `error`: エラー情報
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func refreshAccessToken(completion: @escaping (_ date: Date?, _ error: RESTError?)->()) {
        let api = IntdashClient.OAuth2API(session: session)
        api.refresh { [weak self] (response, error) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let response = response else {
                completion(nil, nil)
                return
            }
            self?.save()
            print("success to refresh token. expires in: \(response.expiresIn)")
            completion(Date(timeInterval: TimeInterval(response.expiresIn), since: response.acquiredTime), nil)
        }
    }
    
    //MARK:- Edges
    /// サインインしているエッジ（自分自身）の情報を取得する
    /// - parameter completion: 処理終了時のコールバック`(response, error)->()`, `response`: レスポンスデータ, `error`: エラー情報
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    public func requestEdgesMe(completion: @escaping (_ response: EdgesMeResponse?, _ error: RESTError?)->()) {
        let api = IntdashClient.EdgesAPI(session: session)
        api.me { (response, error) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let response = response else {
                completion(nil, nil)
                return
            }
            print("success to get sign-in edge information.")
            self.signInEdgeName = response.name
            self.singInEdgeUuid = response.uuid
            completion(response, nil)
        }
    }
    
    /// Edgeのリストを取得します。
    /// - parameter uuid: 取得対象とするエッジのUUID
    /// - parameter order: 取得結果の順序
    /// - parameter limit: 取得対象とする最大のエッジ数
    /// - parameter page: 取得対象とするページ番号
    /// - parameter name: 取得対象とするエッジの名前
    /// - parameter nickname: 取得対象とするエッジの表示名
    /// - parameter type: 取得対象とするエッジのタイプ
    ///   省略した場合全てのタイプを取得対象とします。
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestEdgeList(uuid: String? = nil, order: IntdashClient.EdgesAPI.OrderType = .asc, limit: Int? = nil, page: Int? = nil, name: String? = nil, nickname: String? = nil, type: IntdashClient.EdgesAPI.EdgeType? = nil, completion: @escaping (_ response: EdgesListResponse?, _ error: RESTError?)->()) {
        let api = IntdashClient.EdgesAPI(session: session)
        api.list(uuid: uuid, order: order, limit: limit, page: page, name: name, nickname: nickname, type: type, completion: completion)
    }
    
    //MARK:- Captures
    /// Captureのリストを取得します。
    /// - parameter start: 取得対象とする範囲の始点（UNIXエポックからの経過時間を使用します）
    /// - parameter end: 取得対象とする範囲の終点（UNIXエポックからの経過時間を使用します）
    /// - parameter limit: 取得件数
    /// - parameter page: 取得対象とするページ数
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestCaptureList(start: TimeInterval, end: TimeInterval, limit: Int = 0, page: Int? = nil, completion: @escaping (_ response: CapturesListResponse?, _ error: RESTError?)->()) {
        let api = IntdashClient.CapturesAPI(session: session)
        api.list(start: start, end: end, limit: limit, page: page, completion: completion)
    }
    
    //MARK:- Measurements
    /// Measurementのリストを取得します。
    /// - parameter uuid: 取得対象とする計測のUUID
    /// - parameter name: 取得対象とする計測の名前
    /// - parameter edgeUuid: 取得対象とする計測が紐づくエッジのUUID
    /// - parameter start: 取得対象とする範囲の始点（UNIXエポックからの経過時間を使用します）
    /// - parameter end: 取得対象とする範囲の終点（UNIXエポックからの経過時間を使用します）
    /// - parameter durationStart: 取得対象とする計測の記録期間の始点
    /// - parameter durationEnd: 取得対象とする計測の記録期間の終点
    /// - parameter status: 取得対象とする計測の状態
    /// - parameter limit: 取得対象とする最大の計測数
    /// - parameter page: 取得対象とするページ番号
    /// - parameter order: 取得結果の順序
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestMeasurementList(uuid: String? = nil, name: String? = nil, edgeUuid: String? = nil, start: TimeInterval? = nil, end: TimeInterval? = nil, durationStart: TimeInterval? = nil, durationEnd: TimeInterval? = nil, status: IntdashClient.MeasurementsAPI.Status? = nil, limit: Int? = nil, page: Int? = nil, order: IntdashClient.MeasurementsAPI.OrderType = .asc, completion: @escaping (MeasurementsListResponse?, RESTError?)->()) {
        let api = IntdashClient.MeasurementsAPI(session: session)
        api.list(uuid: uuid, name: name, edgeUuid: edgeUuid, start: start, end: end, durationStart: durationStart, durationEnd: durationEnd, status: status, limit: limit, page: page, order: order, completion: completion)
    }
    
    //MARK:- DataPoints
    /// DataPointのリストを取得します。
    /// - parameter name: 取得対象とする検索名
    ///   計測のUUID、エッジのUUID、エッジの名前を検索対象とし、計測のUUID > エッジのUUID > エッジの名前の順に優先して検索されます。
    /// - parameter filters: どのデータを取得するかを指定するフィルター
    /// - parameter start: 取得対象とする範囲の始点（UNIXエポックからの経過時間を使用します）
    /// - parameter end: 取得対象とする範囲の終点（UNIXエポックからの経過時間を使用します）
    /// - parameter limit: 取得する最大のデータポイント数
    /// - parameter order: 取得結果の順序
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestDataPoints(name: String, filters: IntdashClient.DataPointsAPI.RequestFilters?, start: TimeInterval, end: TimeInterval, limit: Int = -1, order: IntdashClient.DataPointsAPI.OrderType = .asc, completion: @escaping (_ response: DataPointsGetDataPointsResponse?, _ error: RESTError?)->()) {
        let api = IntdashClient.DataPointsAPI(session: session)
        api.getDataPoints(name: name, filters: filters, start: start, end: end, limit: limit, order: order, completion: completion)
    }
    
    //MARK:- Versions
    /// APIバージョンを取得します。
    /// - parameter completion: 処理終了時のコールバック
    /// - parameter response: レスポンスデータ
    /// - parameter error: エラー情報
    func requestAPIVersion(completion: @escaping (VersionsGetVersionInfoResponse?, RESTError?)->()) {
        let api = IntdashClient.VersionsAPI(session: session)
        api.getVersionInfo(completion: completion)
    }
}
