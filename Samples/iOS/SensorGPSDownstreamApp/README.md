# Sensor & GPS Downstream App Sample
このサンプルアプリは、他のエッジのセンサーデータやGPSデータをサーバー経由でリアルタイムに受信し、可視化する方法を示すサンプルです。

intdashへのログイン、対象のエッジの選択、ダウンストリームの開始、データ取得までの一連の流れが実装されています。

※このアプリはiPhone、iPadの `実機のみ` で動作します。

## ■ このサンプルアプリが受信するデータ

- チャンネル: 1
    - `./Classes/Config.swift/GPS_INTDASH_TARGET_CHANNEL` に定義されています(GPS専用) 
    - `./Classes/Config.swift/SENSOR_INTDASH_TARGET_CHANNEL` に定義されています(センサー専用) 
-  データタイプ
    - GeneralSensor
        - センサー種別
            - Acceleration
            - Gravity
            - RotationRate
            - Orientation Angle
            - GeoLocation Coordinate
            - GeoLocation Heading
    - Float
        - データID
            - `"lat"`
                - `./Classes/Config.swift/GPS_PRIMITIVE_DATA_LATITUDE_ID` で定義されています。
            - `"lng"`
                - `./Classes/Config.swift/GPS_PRIMITIVE_DATA_LONGITUDE_ID` で定義されています。
            - `"head"`
                - `./Classes/Config.swift/GPS_PRIMITIVE_DATA_HEAD_ID` で定義されています。
