# Video Upstream App Sample
このサンプルアプリは、動画データ（M-JPEG）をintdashサーバーに送信する方法を示すサンプルです。
intdashへのログイン、動画データの取得、データの送信、計測終了後の再送信までの一連の流れが実装されています。

※このサンプルではH.264やH.265のような高度なエンコード方法は実装されていません。

※このアプリはiPhone、iPadの `実機のみ` で動作します。

## ■ このサンプルアプリが送信するデータ

- チャンネル: 1
    - `./Classes/Config.swift/INTDASH_TARGET_CHANNEL` で定義されています。
- データタイプ
    - JPEG

※ H.264による動画データの送信や、PCMやAACによる音声データの送信は、このサンプルアプリの方法ではできません。intdash Media SDK for Swift-iOSを使用する必要があります。

