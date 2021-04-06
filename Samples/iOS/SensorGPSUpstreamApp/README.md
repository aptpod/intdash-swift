# Sensor & GPS Upstream App Sample
このサンプルアプリは、iOSデバイスのセンサーデータとGPSデータをintdashサーバーに送信する方法を示すサンプルです。
intdashへのログイン、センサーデータの取得、データの送信、計測終了後の再送信までの一連の流れが実装されています。

※このアプリはiPhone、iPadの `実機のみ` で動作します。

## ■ このサンプルアプリが送信するデータ

- チャンネル: 1
    - `./Classes/Config.swift/GPS_INTDASH_TARGET_CHANNEL` に定義されています。(GPS専用) 
    - `./Classes/Config.swift/SENSOR_INTDASH_TARGET_CHANNEL` に定義されています。(センサー専用) 
-  データタイプ
    - GeneralSensor
        - センサー種別
            - Acceleration
            - Gravity
            - Rotation Rate
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

※ GPSによる位置情報は `GeneralSensor` または `Float` のどちらかのiSCPデータタイプで送信されます。

`./Classes/Config.swift/GPS_IS_PRIMITIVE_DATA` を `false` にすると、位置情報は `GeneralSensor` タイプで送信されます。このとき、緯度と経度はまとめてGeoLocation Coordinateとして、方角はGeoLocation Headingとして送信されます。

`./Classes/Config.swift/GPS_IS_PRIMITIVE_DATA` を `true` にすると、緯度、経度、方角がそれぞれ `Float` タイプで送信されます。
