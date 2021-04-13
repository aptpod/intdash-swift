# Motion Plugin App Sample
このサンプルアプリは、 `intdash Motion(※以下、Motion)` と連携してintdashサーバーへデータを送信するプラグインアプリのサンプルです。

Motionとの通信にはUDP(User Datagram Protocol)を利用します。

※iOS、macOS標準で送受信可能なUDPの最大パケットサイズは `9216byte` です。

Motionがフォアグラウンドで動作するため、プラグインアプリはバックグラウンドで動作することを前提としています。
そのため、プラグインアプリでは、BluetoothやGPS関連のバックグランドでの動作が許された処理しか実行できません。また、カメラは利用できません。

※このアプリケーションはiPhone、iPadの `実機のみ` で動作します。

## ■ 新しくMotion用プラグインアプリを作る際のポイント

新しくMotion用のプラグインを作る場合は、以下にご注意ください。

### 1. Info.plistの設定

Info.plistでいくつかの項目を追加する必要があります。

```
// Motionを別アプリから起動するためにスキームを追加
// `Motion` アプリのスキーム名は `aptpod.motion` です。

|Key                         |Type       |Value         |
|----------------------------|-----------|--------------|
|LSApplicationQueriesSchemes |Array      |              |
|item 0                      |String     |aptpod.motion |

// Bluetoothを利用する場合は理由を記述

|Key                                              |Type   |Value             |
|-------------------------------------------------|-------|------------------|
|Privacy - Bluetooth Always Usage Description     |String |デバイスとの接続に利用します。 |
|Privacy - Bluetooth Peripheral Usage Description |String |デバイスとの接続に利用します。 |

// Bluetoothをバックグラウンドで利用する設定(セントラルデバイスデバイスとして)

|Key                       |Type   |Value                                 |
|--------------------------|-------|--------------------------------------|
|Required background modes |Array  |                                      |
|item 0                    |String | App communicates using CoreBluetooth |
```

### 2. Motion用プラグインで使用できるメッセージ

Motion用プラグインからMotionへは、以下のようなメッセージを送信することができます。

メッセージパケットを生成する方法については、この下の「Motionに送信するパケットの生成」を参照してください。

* データポイントを表すメッセージ

    ```
    "{
      \"t\": \"\(time)\",
      \"d\": \"\(data.base64EncodedString())\"
    }"
    ```

* プラグインアプリ名を表すメッセージ

    ```
    "{
      \"name\": \"アプリ名\"
    }"
    ```

* 送信終了を表すメッセージ

    ```
    "{
      \"end\": \"\(true)\"
    }"
    ```

### 3. Motionに送信するパケットの生成

Motionに送信するメッセージのパケットは、以下のように生成します。

#### 3.1 データポイントを送信する場合、バイナリデータに変換する

```swift
// 1. IntdashDataを用意する。
// 以下の例では、TestMessageという文字列にTest-Message-IDというIDを付与し、
// IntdashDataのサブクラスであるDataStringのインスタンスを生成。
let string = try DataString(id: "Test-Message-ID", data: "TestMessage")
// 2. IntdashPacketHelperを利用し、IntdsahDataをバイナリデータへ変換
let data = try IntdashPacketHelper.generatePackets(units: [string])

// もし同じタイムスタンプで複数のデータを送る場合はIntdashDataを複数同時に送ることも可能。ただしUDPで送る想定なので `65535 byte` より多くならない様に注意する。
let string2 = try DataString(id: "Test-Message-ID-2", data: "TestMessage2")
let data = try IntdashPacketHelper.generatePackets(units: [string, string2])
```

#### 3.2 Motionに送信するパケットを生成する

```swift
let strs = NSMutableString()
strs.append("{")
strs.append("\n  \"t\": \"\(time)\",")
strs.append("\n  \"d\": \"\(data.base64EncodedString())\"")
strs.append("\n}")
let message = String(strs)
guard let messageData = message.data(using: .utf8) else { return }
```

### 4. 送信先のMotionのポート番号

プラグインアプリからMotionにデータを送信する際には、Motionが待ち受けているUDPのポート番号を指定する必要があります。
Motionは、デフォルト設定では `12345` ポートで待ち受けています。

```swift
guard let port = NWEndpoint.Port(rawValue: NWEndpoint.Port.RawValue(12345)) else {
  return
}
self.connection = NWConnection(host: "localhost", port: port, using: .udp)
self.connection?.stateUpdateHandler = { (newState) in
  ...
}
self.connection?.start(queue: .global())
```

（サンプルアプリでは、送信先Motionのポート番号は `./Classes/Config.swift/PORT_NUMBER_DEFAULT` で定義しています。）
