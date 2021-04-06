# Video Downstream App Sample

このサンプルアプリは、他のエッジからintdashサーバーに送信されている動画データ(M-JPEG)をリアルタイムにサーバーから取得し、可視化する方法を示すサンプルです。
intdashへのログイン、対象エッジの選択、ダウンストリーム開始、データ取得までの一連の流れが実装されています。  

※このサンプルではH.264やH.265のような高度なエンコード方法は実装されていません。

※このアプリはiPhone、iPadの `実機のみ` で動作します。

## このサンプルが受信するデータ

- チャンネル: 1
    - `./Classes/Config.swift/INTDASH_TARGET_CHANNEL_DEFAULT` に定義 
-  データタイプ
    - JPEG

※ H.264による動画データの受信や、PCMやAACによる音声データの受信は、このサンプルアプリの方法ではできません。intdash Media SDK for Swift-iOSを使用する必要があります。
