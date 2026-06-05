Offline Egress Traffic Analyzer

(ローカルAI環境向け 完全オフライン通信監査ツール)

概要 (Overview)

ローカル環境で稼働させるAIモデル（LLM等）が、意図せず外部サーバーへ機密データを送信していないかを検証するための、パケット解析・監査ツールです。

「自端末のログを外部APIに渡さない」という**データ主権（Data Sovereignty）の原則に基づき、パケット解析からGeoIP/ASNのエンリッチメント（情報付加）まで、すべての処理を完全オフライン環境（インターネット切断状態）**で実行できるアーキテクチャを採用しています。

開発の背景 (Motivation)

ローカルLLMの活用が進む中、モデルの背後で発生するテレメトリ通信や、悪意あるプロンプトインジェクションによる外部へのデータ流出（Egress Traffic）のリスクが高まっています。
本ツールは、L3/L4（ネットワーク・トランスポート層）のパケットを直接監視することで、アプリケーション層のログには残らない「隠れた通信」を可視化し、システム全体のセキュリティガバナンスを証明するために開発しました。

主な機能 (Features)

• 自動Egress検知: Pythonの ipaddress モジュールを利用し、自端末（プライベートIP）からインターネット（パブリックIP）へ向かう通信のみを自動抽出。自IPの手動設定は不要です。

• 完全オフラインの脅威分析: MaxMind社のGeoLite2ローカルデータベースを統合。外部のOSINT系APIに依存することなく、通信先の「国名」および「組織名（ASN/ISP）」を一瞬で特定します。

• 複数PCAPのバルク処理: フォルダ内の複数キャプチャファイル（.pcapng / .pcap）を自動検知し、アグリゲーション（集約）して一括解析します。

• SOC向けレポート出力: 解析結果を集計し、通信回数順にソートした監査レポート（CSVフォーマット）を出力します。

技術スタック (Tech Stack)

• 言語: Python 3.10+

• パケット解析エンジン: TShark (Wireshark) / pyshark

• ローカルDB解析: geoip2 (MaxMind GeoLite2 City / ASN)

• データ処理: csv, ipaddress, glob

GeoLite データベースの配置

MaxMind GeoLite2 は **`geolite/` ディレクトリに統一**してください（`python/` 内の重複コピーは使用しません）。スクリプトは `geolite/**/GeoLite2-City.mmdb` と `GeoLite2-ASN.mmdb` を自動検出します。

使用方法 (Usage)

1. 事前準備

1. Wireshark（TShark）がシステムにインストールされていることを確認します。

2. 必要なPythonライブラリをインストールします。
pip install -r requirements.txt

	（`pyshark` / `geoip2` / `mac-vendor-lookup` が入ります）

	※ 完全オフラインで実行する場合、MACベンダー DB の自動更新（`MacLookup.update_vendors()`）は
	  ネットワークへアクセスしようとします。オフライン時は更新がスキップされ、`mac-vendor-lookup`
	  に同梱の既存 DB が使われます（処理は継続します）。

3. MaxMind公式サイトより以下の無料データベース（.mmdb）をダウンロードし、`geolite/` ディレクトリに配置します（`*.mmdb` は容量とライセンスの都合でリポジトリには含めていません）。

	• GeoLite2-City.mmdb

	• GeoLite2-ASN.mmdb

2. 実行手順

解析したいPCAPファイル（複数可）をスクリプトと同じディレクトリに配置し、以下のコマンドを実行します。
python3 analyze_ai_traffic.py

3. 出力例 (Output Example)


user@example-host portfolio % python3 analyze_ai_traffic.py
以下の 2 個のファイルを一括解析します:
 - analyze_traffic.pcapng
 - local_ai_traffic.pcapng

解析中: analyze_traffic.pcapng ...

解析中: local_ai_traffic.pcapng ...

=== 全ファイルの解析完了 ===
総パケット数: 34395
Egress（プライベート→パブリック）パケット数: 4503
集約された Egress 通信ペア数: 19
結果を analysis_report.csv に保存しました。


実行完了後、analysis_report.csv が生成されます（プライベート→パブリックの Egress 通信のみ）。

Source IP	Source Country	Source Organization	Destination IP	Dest Country	Dest Organization	Total Packet Count
192.168.1.10	Private Network	Apple [xx:xx:xx:xx:xx:xx]	198.51.100.10	United States	Amazon.com, Inc. (CloudFront)	4420
192.168.1.10	Private Network	Apple [xx:xx:xx:xx:xx:xx]	198.51.100.11	Japan	Yahoo Japan	68
192.168.1.10	Private Network	Apple [xx:xx:xx:xx:xx:xx]	203.0.113.1	United States	Google LLC	15

考察とユースケース (Analysis & Use Cases)

• ローカルAIの安全性証明: AI稼働時のPCAPファイルを読み込ませ、出力結果が「0件」であることを以て、クローズドネットワークでの安全性を技術的に証明可能。

• サプライチェーン通信の可視化: 通常のWebブラウジング通信を解析することで、ユーザーが直接アクセスしたドメインの背後にあるCDN（AWS CloudFront, Cloudflare, Fastly等）やトラッカーへのバックグラウンド通信を可視化。意図しないシャドーITの発見に寄与します。