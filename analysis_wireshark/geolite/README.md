# GeoLite2（ローカル配置用・Git には含めない）

MaxMind GeoLite2 の `.mmdb` は **ライセンス上リポジトリに含めていません**。  
各自 [MaxMind](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data) から取得し、このディレクトリに置いてください。

## 必要なファイル

- `GeoLite2-City.mmdb`（または `GeoLite2-City_YYYYMMDD/GeoLite2-City.mmdb`）
- `GeoLite2-ASN.mmdb`（または `GeoLite2-ASN_YYYYMMDD/GeoLite2-ASN.mmdb`）

`analyze_ai_traffic.py` は `geolite/` 配下を自動検出します。

## 注意

- `python/` 内の GeoLite コピーは**使わない**（重複・誤コミット防止のためリポジトリ外推奨）
