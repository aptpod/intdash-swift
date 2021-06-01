# intdash SDK for Swift

[ドキュメントホーム](https://docs.intdash.jp/sdk/swift/latest/)

## ■ このSDKを使用するために必要な開発環境

- Xcode 11.3以上

## ■ 動作環境

- iOS 12以上

## ■ 事前準備

1\. intdashサーバーの管理者からOAuth2.0のクライアントIDを入手します。  
（例：`abcdefg123456`）  
2\. これから開発するアプリケーションのコールバックスキーム名を決め、intdashサーバーの管理者へスキーム名の登録を依頼してください。  
（例： `companyname.appname`）  
3\. `Info.plist` の `URL Types`で、以下のようにコールバックスキームを登録します。  
例)
	
    |Key                |Type       |Value                             |
    |-------------------|-----------|----------------------------------|
    |- URL types        |Array      |                                  |
    | - Item 0 (Viewer) |Dictionary |                                  |
    |  - Document Role  |String     |Viewer                            |
    |  - URL identifier |String     |$(PRODUCT_BUNDLE_IDENTIFIER)      |
    |  - URL Schemes    |Array      |                                  |
    |   - Item 0        |String     |スキーム名（例：companyname.appname）   |

4\. `Intdash.xcframework` をプロジェクトに追加します。  

※ 手動で開発するプロジェクトへフレームワークを追加した場合は `Embed & Sign` としてください。

### Cocoapods
このフレームワークは [CocoaPods](http://cocoapods.org) からも入手可能です、`Podfile` に以下を追加してください。

```ruby
pod 'Intdash'
```

## ■ 実装

### ・認証

1\. フレームワークをインポートする。  
2\. `IntdashClient.Session` を初期化する。  
3\. `IntdashClient.OAuth2API` を初期化する。  
4\. Web認証用URLを生成する。  
5\. 認証を開始する。  
6\. 認証結果が正しいかチェックする。  
7\. 正常に認証ができていれば認証コードを利用してアクセストークンを取得する。  
8\. 必要に応じて、サインインしたエッジ（自分自身）の情報を取得する。  

```swift
// 1. フレームワークをインポートする。
import Intdash
import AuthenticationServices

// intdashサーバー名
let kTargetServer: String = "https://example.com"
// OAuth2.0 クライアントID
let kIntdashClientId: String = "abcdefg123456"
// コールバックスキームを使用したコールバックURL
let kCallbackURLScheme: String = "companyname.appname://oauth2/callback"

class ExampleViewController: UIViewController {

    var session: IntdashClient.Session?
    var signInEdgeUuid: String?
    var signInEdgeName: String?
    
    private var webAuthSession: NSObject?

    func signIn() {
        guard #available(iOS 12.0, *) else {
            print("Unsupported OS")
            return
        }
        // 2. `IntdashClient.Session` を初期化する。
        let session = IntdashClient.Session(serverURL: kTargetServer, clientId: kIntdashClientId)
        self.session = session
        // 3. `IntdashClient.OAuth2API` を初期化する。
        let oauth2Api = IntdashClient.OAuth2API(session: session)
        // 4. Web認証用URLを生成する。
        let callbackURLScheme = kCallbackURLScheme.replacingOccurrences(of: ":", with: "%3A").replacingOccurrences(of: "/", with: "%2F") // URLエンコード
        oauth2Api.generateAuthorizationURL(callbackURLScheme: callbackURLScheme) { [weak self] (url, codeVerifier, state, error) in
            guard error == nil, let url = url, let authURL = URL(string: url), let codeVerifier = codeVerifier else {
                print("generateAuthorizationURL failed. \(error?.localizedDescription ?? "")")
                return
            }
            // 5. 認証を開始する。
            let webAuthSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackURLScheme) { (callbackURL, error) in
                guard error == nil, let callbackURL = callbackURL else {
                    print("Web authentication callback error. \(error?.localizedDescription ?? "")")
                    return
                }
                // 6. 認証結果が正しいかチェックする。
                var result = false
                var code: String?
                if let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems {
                    for item in queryItems {
                        if item.name == "state", item.value == state {
                            result = true
                        }
                        if item.name == "code" {
                            code = item.value
                        }
                    }
                }
                if let code = code, result {
                    print("Web authentication was successful.")
                    // 7. 正常に認証ができていれば認証コードを利用してアクセストークンを取得する。
                    // (※このとき `IntdashClient.Session` の認証情報はフレームワーク側で自動で更新されます。)
                    oauth2Api.authenticate(code: code, codeVerifier: codeVerifier, callbackURLScheme: kCallbackURLScheme) { (response, error) in
                        if let error = error {
                            print("requestAccessToken failed. \(error.localizedDescription)")
                            return
                        }
                        // 8. 必要に応じて、サインインしたエッジ（自分自身）の情報を取得する。
                        // (※このあとデータのアップストリームを行う場合はエッジのUUIDが必要です。)
                        let edgesApi = IntdashClient.EdgesAPI(session: session)
                        edgesApi.me { (response, error) in
                            guard let response = response else {
                                print("requestEdgesMe failed. \(error?.localizedDescription ?? "")")
                                return
                            }
                            print("Successful sign-in.")
                            self?.signInEdgeName = response.name
                            self?.signInEdgeUuid = response.uuid
                        }
                    }
                }
            }
            if #available(iOS 13.0, *) {
                webAuthSession.presentationContextProvider = self
                webAuthSession.prefersEphemeralWebBrowserSession = false
            }
            
            // Start
            self?.webAuthSession = webAuthSession
            webAuthSession.start()
        }
    }
}

extension ExampleViewController: ASWebAuthenticationPresentationContextProviding {
    
    @available(iOS 12.0, *)
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first ?? ASPresentationAnchor()
    }
    
}


```

### ・エッジ、計測、キャプチャーなどintdash APIが提供するリソースの取得

例として、ここではエッジの一覧を取得します。

1\. `IntdashClient` を初期化する。  
2\. 認証情報がセットされた `IntdashClient.Session` をセットする。  
3\. エッジの一覧を取得する。  

```swift
// 1. IntdashClientを初期化する。
let intdash = IntdashClient()

// 2. 認証情報がセットされた `IntdashClient.Session` をセットする。
intdash.session = self.session

// 3. エッジの一覧を取得する。
intdash.edges.list { (response, error) in
    guard let response = response else {
        print("requestEdgeList failed. \(error?.localizedDescription ?? "")")
        return
    }
    print("successful request for edge list. \(response.items.count) edges")
    for item in response.items {
        print("\(item.name) [\(item.uuid) ")
    }
}
```

### ・リアルタイムデータのダウンストリームを行う

1\. `IntdashClient` を初期化する。  
2\. 認証情報がセットされた `IntdashClient.Session` をセットする。  
3\. `IntdashClient.DownstreamManager` のデリゲートを設定する。  
4\. intdashサーバーとの接続を開始する。  
5\. ダウンストリームを開く。  
6\. ダウンストリームフィルター(`IntdashClient.DownstreamManager.RequestFilters`)を生成する。  
7\. ダウンストリーム情報をintdashサーバーと同期する。  

```swift
var intdash: IntdashClient?
var downstreamIds: [Int]?

/// ダウンストリームを行う対象のエッジのUUID
var downstreamTargetEdgeUuid = "" // 必要に応じて変更
/// ダウンストリームを行う対象のエッジのチャンネル番号
var targetChannel: Int = 1 // 必要に応じて変更

func startDownsteram() {
    // 1. `IntdashClient` を初期化する。
    let intdash = IntdashClient()
    // 2. 認証情報がセットされた `IntdashClient.Session` をセットする。
    intdash.session = self.session
    self.intdash = intdash
    // 3. `IntdashClient.DownstreamManager` のデリゲートを設定する。
    intdash.downstreamManager.addDelegate(delegate: self) // IntdashClientDownstreamManagerDelegate
    // 4. intdashサーバーとの接続を開始する。
    intdash.connect { [weak self] (error) in
        if let error = error {
            print("Failed to connect to the intdash server. \(error.localizedDescription)")
            return
        }
        // 5. ダウンストリームを開く。
        let streamId: Int
        do {
            streamId = try intdash.downstreamManager.open(srcEdgeId: self!.downstreamTargetEdgeUuid)
        } catch {
            print("Failed to open downstream. \(error)")
            return
        }
        if self?.downstreamIds == nil {
            self?.downstreamIds = [streamId]
        } else {
            self?.downstreamIds?.append(streamId)
        }
        // 6. ダウンストリームフィルター(`IntdashClient.DownstreamManager.RequestFilters`)を生成する。
        let downstreamFilter = self?.makeDownstreamFilters(streamId: streamId, channel: self!.targetChannel)
        // 7. ダウンストリーム情報をintdashサーバーと同期する。(※downstreamFiltersにnilを指定すると、全チャンネル、全データタイプ、全IDのデータを受信します)
        intdash.downstreamManager.sync(completion: { (errors) in
            if let errors = errors {
                print("Failed to request dowsntream. \(errors)")
                return
            }
            print("Success to downstream request.")
        }, filters: downstreamFilter)
    }
}
```

#### ダウンストリームフィルターの生成方法

8\. `IntdashClient.DownstreamManager.RequestFilters` を初期化する。  
9\. ダウンストリームするデータの情報を追加する。  

```swift
func makeDownstreamFilters(streamId: Int, channel: Int) -> IntdashClient.DownstreamManager.RequestFilters? {
    // 8. `IntdashClient.DownstreamManager.RequestFilters` を初期化する。
    let downstreamFilters = IntdashClient.DownstreamManager.RequestFilters()

    // 9. ダウンストリームするデータの情報を追加する。
    // フィルターが必要ない(全チャンネル、データを対象とする)場合は何もappendしない。
    // 「チャンネル1、データタイプGeneralSensor、ID 1,3,4」を追加する場合
    downstreamFilters.append(streamId: streamId, channelNum: 1, dataType: .generalSensor, ids: [1, 3, 4])
    // 「チャンネル1、データタイプH.264、IDなし」を追加する場合
    downstreamFilters.append(streamId: streamId, channelNum: channel, dataType: .h264, id: nil)

    // フィルターが追加されなかった場合は全開放ファイルターとして扱われます。
    return downstreamFilters
}  
```

#### ダウンストリームされたデータの取得方法

10\. `IntdashClientDownstreamManagerDelegate.downstreamManagerDidParseDataPoints` から `RealtimeDataPoint` の配列を取得する。  

```swift
extension ExampleViewController: IntdashClientDownstreamManagerDelegate {
    
    // 10. `IntdashClientDownstreamManagerDelegate.downstreamManagerDidParseDataPoints` から `RealtimeDataPoint` の配列を取得する。
    func downstreamManagerDidParseDataPoints(_ manager: IntdashClient.DownstreamManager, streamId: Int, dataPoints: [RealtimeDataPoint]) {
        for dataPoint in dataPoints {
            switch dataPoint.dataModel.dataType {
                // ...
            default: break
            }
        }
    }
        
}
```

#### ダウンストリームを終了する

11\. ダウンストリームを閉じる。  
12\. 閉じられているダウンストリームを削除する。  
13\. intdashサーバーとの接続を終了する。(※終了する場合)  

```swift
func stopDownstream() {
    guard let intdash = self.intdash else { return }
    self.intdash = nil
    let group = DispatchGroup()
    if let streamIds = self.downstreamIds {
        self.downstreamIds = nil
        group.enter()
        DispatchQueue.global().async {
            // 11. ダウンストリームを閉じる。
            intdash.downstreamManager.close(streamIds: streamIds) { (error) in
                if let error = error {
                    print("Failed to close downstream. \(error.localizedDescription)")
                } else {
                    print("Success to close downstream.")
                }
                // 12. 閉じられたダウンストリームを削除する。
                intdash.downstreamManager.removeClosedDownstream()
                group.leave()
            }
        }
    }
    
    group.notify(queue: .global()) {
        // 13. intdashサーバーとの接続を終了する。(※終了する場合)
        intdash.disconnect { (error) in
            if let error = error {
                print("Failed to disconnect to the intdash server. \(error.localizedDescription)")
            } else {
                print("Success to disconnect to the intdash server.")
            }
        }
    }
}
```


### ・リアルタイムデータのアップストリームを行う(新しい計測を開始し、サーバーにリアルタイムデータを送信する)

1\. `IntdashClient` を初期化する。  
2\. 認証情報がセットされた `IntdashClient.Session` をセットする。  
3\. `IntdashClient.UpstreamManager` のデリゲートを設定する。(※セクション情報の管理やAckの確認を行いたい場合のみ)  
4\. intdashサーバーとの接続を開始する。  
5\. 計測IDを取得する。  
6\. アップストリームを開く。  
7\. アップストリーム情報をintdashサーバーと同期する。  
8\. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager` を初期化する。  
9\. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager.setMeasurementId()` で計測IDを保存する。  

```swift
//var intdash: IntdashClient?
var upstreamId: Int?
var upstreamIds: [Int]?

/// アップストリームを行うチャンネル番号(※ストリームごとに別のチャンネル番号を設定することができます)
//var targetChannel: Int = 1 // 必要に応じて変更

/// iOSデバイス内にデータを保存する場合に使用するファイルマネージャー
var intdashDataFileManager: IntdashDataFileManager?
/// intdashサーバーへ保存するかの選択
var isSaveToServer: Bool = true
/// intdashデータを保存するディレクトリのパス
var intdashDataFileParentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

func startUpstream() {
    guard let edgeUuid = self.signInEdgeUuid else { return }
    // 1. `IntdashClient` を初期化する。
    let intdash = IntdashClient()
    self.intdash = intdash
    // 2. 認証情報がセットされた `IntdashClient.Session` をセットする。
    intdash.session = self.session
    // 3. IntdashClient.UpstreamManagerのデリゲートを設定する。(※セクション情報の管理やAckの確認を行いたい場合のみ)
    intdash.upstreamManager.addDelegate(delegate: self) // IntdashClientUpstreamManagerDelegate
    // 4. intdashサーバーとの接続を開始する。
    intdash.connect { [weak self] (error) in
        if let error = error {
            print("Failed to connect to the intdash server. \(error.localizedDescription)")
            return
        }
        // 5. 計測IDを取得する。
        intdash.upstreamManager.requestMeasurementId(edgeUuid: edgeUuid) { [weak self] (measurementId, error) in
            guard let measurementId = measurementId else {
                print("Failed to requestMeasurementId. \(error?.localizedDescription ?? "")")
                return
            }
            // 6. アップストリームを開く。
            let streamId: Int
            do {
                // データをサーバーに保存する場合は `store` を `true` にしてください。
                streamId = try intdash.upstreamManager.open(measurementId: measurementId, srcEdgeId: edgeUuid, store: self!.isSaveToServer)
            } catch {
                print("Failed to open upstream. \(error)")
                return
            }
            self?.upstreamId = streamId
            if self?.upstreamIds == nil {
                self?.upstreamIds = [streamId]
            } else {
                self?.upstreamIds?.append(streamId)
            }
            // 7. アップストリーム情報をintdashサーバーと同期する。
            intdash.upstreamManager.sync { [weak self] (error) in
                if let error = error {
                    print("Failed to request upstream. \(error)")
                    return
                }
                print("Success to request upstream.")
                if self!.isSaveToServer {
                    do {
                        // 8. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager` を初期化する。
                        let fileManager = try IntdashDataFileManager(parentPath: "\(self!.intdashDataFileParentPath)/\(measurementId)")
                        // 9. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager.setMeasurementId()` で計測IDを保存する。
                        try fileManager.setMeasurementId(id: measurementId)
                        self?.intdashDataFileManager = fileManager
                    } catch {
                        print("Failed to setup file manager. \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

extension ExampleViewController: IntdashClientUpstreamManagerDelegate {
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didGeneratedSesion sectionId: Int, sectionIndex: Int, streamId: Int, final: Bool, sentCount: Int, startOfElapsedTime: TimeInterval, endOfElapsedTime: TimeInterval) {
    }
    
    func upstreamManager(_ manager: IntdashClient.UpstreamManager, didReceiveEndOfSection sectionId: Int, streamId: Int, success: Bool, final: Bool, sentCount: Int) {
    }
    
}
```

#### アップストリームするデータの送信

10\. iOSデバイス内にデータを保存する場合は、計測開始時刻を `IntdashDataFileManager.setBaseTime()` で保存しておく。  
11\. 基準となる計測開始時刻を `IntdashClient.UpstreamManager.sendFirstData()` で送信する。  
12\. 送信したいデータを、 `IntdashData` のサブクラスでラップする。  
13\. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager.write()` でデータを保存する。  
14\. 生成したデータを `IntdashClient.UpstreamManager.sendUnit()` で送信する。  
15\. 12、(13)、14を任意の時間または回数だけ繰り返す。  

```swift
var baseTime: TimeInterval = -1
    
func sendFirstData(baseTime: TimeInterval, streamId: Int, channel: Int) {
    self.baseTime = baseTime
    guard let intdash = self.intdash else { return }
    do {
        // 10. iOSデバイス内にデータを保存する場合は、計測開始時刻を `IntdashDataFileManager.setBaseTime()` で保存しておく。
        try self.intdashDataFileManager?.setBaseTime(time: baseTime)
        // 11. 基準となる計測開始時間を `IntdashClient.UpstreamManager.sendFirstData()` で送信する。
        try intdash.upstreamManager.sendFirstData(baseTime, streamId: streamId, channelNum: channel)
    } catch {
        print("Failed to send first data. \(error.localizedDescription)")
        return
    }
}

func generateData() {
    guard let streamId = self.upstreamId else { return }
    let timestamp = Date().timeIntervalSince1970
    if self.baseTime == -1 {
        self.sendFirstData(baseTime: timestamp, streamId: streamId, channel: self.targetChannel)
    }
    let value: Int = 1
    // 12. 送信したいデータを、 `IntdashData` のサブクラスでラップする。
    // データの種別に関しては「詳説iSCP 1.0」を参照してください。
    guard let data = try? IntdashData.DataInt(id: "intdash-data-example-id", data: Int64(value)) else { return }
    self.sendData(data: data, streamId: streamId, timestamp: timestamp)
}

func sendData(data: IntdashData, streamId: Int, timestamp: TimeInterval) {
    guard let intdash = self.intdash else { return }
    let elapsedTime = timestamp - self.baseTime
    guard elapsedTime >= 0 else { return }
    DispatchQueue.global().async {
        do {
            // 13. iOSデバイス内にデータを保存する場合は `IntdashDataFileManager.write()` でデータを保存する。
            if let fileManager = self.intdashDataFileManager {
                if let fileManager = self.intdashDataFileManager {
                    _ = try fileManager.write(units: [data], elapsedTime: elapsedTime)
                }
            }
            // 14. 生成したデータを`IntdashClient.UpstreamManager.sendUnit()` で送信する。
            try intdash.upstreamManager.sendUnit(data, elapsedTime: elapsedTime, streamId: streamId)
        } catch {
            print("Failed to send data. \(error.localizedDescription)")
            return
        }
    }
}
```

#### アップストリーム(計測)を終了する。

16\. iOSデバイスにデータを保存している場合は、計測時間を `IntdashDataFileManager.setDuration()` で保存する。  
17\. 計測の終了を示すデータを送信する。  
18\. アップストリームを閉じる。  
19\. 閉じられているアップストリームを削除する。  
20\. intdashサーバーとの接続を終了する。(※終了する場合)  

```swift
func stopUpstream() {
    guard let intdash = self.intdash else { return }
    self.intdash = nil
    // 16. iOSデバイスにデータを保存している場合は、計測時間を `IntdashDataFileManager.setDuration()` で保存する。
    let now = Date().timeIntervalSince1970 // 時間管理をDate()で行っている場合
    let duration = now-self.baseTime
    try? self.intdashDataFileManager?.setDuration(duration: duration)
    self.intdashDataFileManager = nil
    
    let group = DispatchGroup()
    if let streamId = self.upstreamId {
        self.upstreamId = nil
        do {
            // 17. 計測の終了を示すデータを送信する。
            try intdash.upstreamManager.sendLastData(streamId: streamId)
        } catch {
            print("Failed to send last data. \(error.localizedDescription)")
        }
                    
        if let streamIds = self.upstreamIds {
            self.upstreamIds = nil
            group.enter()
            DispatchQueue.global().async {
                // 18. アップストリームを閉じる。
                intdash.upstreamManager.close(streamIds: streamIds) { (error) in
                    if let error = error {
                        print("Failed to close upstream. \(error.localizedDescription)")
                    } else {
                        print("Success to close upstream.")
                    }
                    // 19. 閉じられているアップストリームを削除する。
                    intdash.upstreamManager.removeClosedUpstream()
                    group.leave()
                }
            }
        }
    }
    
    group.notify(queue: .global()) {
        // 20. intdashサーバーとの接続を終了する。(※終了する場合)
        intdash.disconnect { (error) in
            if let error = error {
                print("Failed to disconnect to the intdash server. \(error.localizedDescription)")
            } else {
                print("Success to disconnect to the intdash server.")
            }
        }
    }
}
```

## ■ 使用している外部ライブラリ
- [SwiftWebSocket](https://github.com/tidwall/SwiftWebSocket/blob/master/Source/WebSocket.swift)
    - ライセンス：MIT
