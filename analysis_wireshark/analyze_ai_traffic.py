import csv
import glob
import ipaddress
from pathlib import Path

import geoip2.database
import pyshark
from mac_vendor_lookup import MacLookup

# GeoLite DB は geolite/ 配下に統一（python/ 内の重複コピーは使わない）
GEOLITE_DIR = Path(__file__).resolve().parent / "geolite"


def resolve_geolite_db(pattern: str) -> str:
    matches = sorted(GEOLITE_DIR.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"GeoLite DB not found under {GEOLITE_DIR}: {pattern}")
    return str(matches[0])


def get_ip_info_local(ip, city_reader, asn_reader):
    try:
        if ipaddress.IPv4Address(ip).is_private:
            return "Private Network", "Local Device"
    except ValueError:
        pass

    country, org = "Unknown", "Unknown"

    try:
        city_response = city_reader.city(ip)
        if city_response.country.name:
            country = city_response.country.name
    except Exception:
        pass

    try:
        asn_response = asn_reader.asn(ip)
        if asn_response.autonomous_system_organization:
            org = asn_response.autonomous_system_organization
    except Exception:
        pass

    return country, org


def analyze_all_captures(city_db, asn_db, output_csv):
    pcap_files = glob.glob("*.pcapng") + glob.glob("*.pcap")
    if not pcap_files:
        print("エラー: .pcap / .pcapng ファイルが見つかりません。")
        return

    print("MACアドレスのベンダーデータベースを準備中...")
    mac_lookup = MacLookup()
    try:
        mac_lookup.update_vendors()
    except Exception:
        print("※ベンダー情報の自動更新をスキップしました（既存のデータを使用します）")

    def get_mac_vendor(mac_address):
        try:
            return mac_lookup.lookup(mac_address)
        except Exception:
            return "Unknown Vendor"

    print(f"\n以下の {len(pcap_files)} 個のファイルを一括解析します:")
    for f in pcap_files:
        print(f" - {f}")

    traffic_data = {}
    total_packets_count = 0

    with geoip2.database.Reader(city_db) as city_reader, geoip2.database.Reader(asn_db) as asn_reader:
        for pcap_file in pcap_files:
            print(f"\n解析中: {pcap_file} ...")
            cap = pyshark.FileCapture(pcap_file, display_filter="ip")

            for packet in cap:
                total_packets_count += 1
                try:
                    if hasattr(packet, "ip") and hasattr(packet, "eth"):
                        src_ip = packet.ip.src
                        dst_ip = packet.ip.dst
                        src_mac = packet.eth.src
                        dst_mac = packet.eth.dst
                        conn_key = (src_ip, dst_ip)

                        if conn_key not in traffic_data:
                            src_country, src_org = get_ip_info_local(src_ip, city_reader, asn_reader)
                            dst_country, dst_org = get_ip_info_local(dst_ip, city_reader, asn_reader)

                            if src_country == "Private Network":
                                vendor = get_mac_vendor(src_mac)
                                src_org = f"{vendor} [{src_mac}]"
                            if dst_country == "Private Network":
                                vendor = get_mac_vendor(dst_mac)
                                dst_org = f"{vendor} [{dst_mac}]"

                            traffic_data[conn_key] = {
                                "src_country": src_country,
                                "src_org": src_org,
                                "dst_country": dst_country,
                                "dst_org": dst_org,
                                "count": 1,
                            }
                        else:
                            traffic_data[conn_key]["count"] += 1
                except Exception:
                    pass
            cap.close()

    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "Source IP",
                "Source Country",
                "Source Organization",
                "Destination IP",
                "Dest Country",
                "Dest Organization",
                "Total Packet Count",
            ]
        )

        for (src_ip, dst_ip), info in sorted(traffic_data.items(), key=lambda x: x[1]["count"], reverse=True):
            writer.writerow(
                [
                    src_ip,
                    info["src_country"],
                    info["src_org"],
                    dst_ip,
                    info["dst_country"],
                    info["dst_org"],
                    info["count"],
                ]
            )

    print("\n=== 全ファイルの解析完了 ===")
    print(f"総パケット数: {total_packets_count}")
    print(f"集約された通信ペア数: {len(traffic_data)}")
    print(f"結果を {output_csv} に保存しました。")


if __name__ == "__main__":
    CITY_DB_PATH = resolve_geolite_db("**/GeoLite2-City.mmdb")
    ASN_DB_PATH = resolve_geolite_db("**/GeoLite2-ASN.mmdb")
    OUTPUT_CSV_FILE = "analysis_report.csv"
    analyze_all_captures(CITY_DB_PATH, ASN_DB_PATH, OUTPUT_CSV_FILE)
