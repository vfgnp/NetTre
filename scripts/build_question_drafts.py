#!/usr/bin/env python3
"""手書き問題の下書きを作る（AI の下書き。人が確認してから questions.json に収録する）。

出力:
  drafts/questions_draft.json  … Question と同じ形（D11）
  drafts/questions_draft_review.md … 確認用の一覧
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")

# (分野, 難易度, タグ, 問題文, 正解, 解説)
Q = {
"network-fundamentals": ("net-fund", 2, [
 (1, ["tcp", "handshake"], "TCP の 3 ウェイハンドシェイクで、接続が確立するまでに送られるセグメントはいくつか。", "3",
  "クライアントの **SYN**、サーバーの **SYN/ACK**、クライアントの **ACK** の **3 つ**で接続が確立する。"),
 (1, ["ipv4", "header"], "IPv4 ヘッダーの TTL フィールドは何ビットか。", "8",
  "TTL は **8 ビット**なので最大値は 255。ルーターを 1 つ通るたびに 1 減り、0 になるとパケットは破棄される。"),
 (2, ["ethernet", "cabling"], "1000BASE-T は UTP ケーブルの何ペアを使って通信するか。", "4",
  "1000BASE-T は **4 ペアすべて**を使い、各ペアで送受信を同時に行う。100BASE-TX は 2 ペアだけを使う。"),
 (2, ["ethernet", "cabling"], "100BASE-TX は UTP ケーブルの何ペアを使って通信するか。", "2",
  "100BASE-TX は送信用と受信用の **2 ペア**を使う（1・2 番ピンと 3・6 番ピン）。"),
 (1, ["ethernet", "cabling"], "UTP ケーブルを使う 1000BASE-T の最大のケーブル長は何メートルか。", "100",
  "10BASE-T・100BASE-TX・1000BASE-T とも、UTP の最大長は **100 m**。"),
 (1, ["ipv6", "address"], "IPv6 アドレスを 16 ビットごとにコロンで区切って書くとき、区切られたフィールドはいくつあるか。", "8",
  "128 ビット ÷ 16 ビット = **8 フィールド**。各フィールドを 4 けたの 16 進数で書く。"),
 (2, ["ethernet", "frame"], "イーサネットフレームの末尾にある FCS は何バイトか。", "4",
  "FCS（フレームチェックシーケンス）は **4 バイト**の CRC。受信側はこれでフレームの誤りを見つける。"),
 (1, ["osi", "layer"], "OSI 参照モデルで、トランスポート層は下から数えて第何層か。", "4",
  "物理（1）・データリンク（2）・ネットワーク（3）・**トランスポート（4）**・セッション（5）・プレゼンテーション（6）・アプリケーション（7）。"),
 (2, ["dhcp", "port"], "DHCP クライアントが使う UDP のポート番号を答えよ。", "68",
  "DHCP は UDP を使い、**クライアントは 68 番**、サーバーは 67 番。"),
 (2, ["ipv4", "private"], "RFC 1918 のプライベートアドレスのうち、192.168.0.0 から始まる範囲のプレフィックス長を答えよ。", "16",
  "RFC 1918 の範囲は 10.0.0.0/8、172.16.0.0/12、**192.168.0.0/16** の 3 つ。"),
]),
"network-access": ("net-access", 2, [
 (1, ["vlan"], "IEEE 802.1Q のタグの中で、VLAN ID を表すフィールドは何ビットか。", "12",
  "VLAN ID は **12 ビット**なので 0〜4095 を表せる。0 と 4095 は予約されている。"),
 (1, ["vlan", "trunk"], "Cisco スイッチのトランクポートで、既定のネイティブ VLAN の ID を答えよ。", "1",
  "既定のネイティブ VLAN は **VLAN 1**。ネイティブ VLAN のフレームはタグなしで送られる。セキュリティのため、使っていない VLAN に変えることが多い。"),
 (2, ["vlan"], "拡張範囲の VLAN ID はいくつから始まるか。", "1006",
  "標準範囲は 1〜1005、拡張範囲は **1006**〜4094。"),
 (2, ["stp", "timer"], "IEEE 802.1D の STP で、フォワード遅延タイマーの既定値は何秒か。", "15",
  "フォワード遅延は **15 秒**。ポートはリスニングとラーニングでそれぞれ 15 秒待つ。"),
 (2, ["stp", "timer"], "IEEE 802.1D の STP で、Max Age タイマーの既定値は何秒か。", "20",
  "Max Age は **20 秒**。この間 BPDU を受け取れないと、トポロジーが変わったとみなす。"),
 (1, ["stp", "timer"], "STP で、ルートブリッジが BPDU を送る間隔（Hello タイマー）の既定値は何秒か。", "2",
  "Hello タイマーは **2 秒**。"),
 (3, ["stp", "cost"], "Cisco スイッチの STP で、短い方式（802.1D-1998）を使うとき、1 Gbps のリンクのパスコストの既定値を答えよ。", "4",
  "短い方式のコストは 10 Mbps が 100、100 Mbps が 19、**1 Gbps が 4**、10 Gbps が 2。"),
 (2, ["etherchannel"], "EtherChannel で、1 つのバンドルの中で同時に転送に使える物理リンクは最大いくつか。", "8",
  "1 つの EtherChannel で同時に使える（アクティブな）リンクは **8 本**まで。LACP では 8 本を超えて設定した分は待機（スタンバイ）になる。"),
 (2, ["wireless"], "2.4 GHz 帯の無線 LAN で、20 MHz 幅のときに互いに重ならないチャネルとしてよく使われるのはいくつか。", "3",
  "**1・6・11 の 3 つ**は周波数が重ならないので、隣り合うアクセスポイントに割り当てる。"),
 (2, ["cdp"], "Cisco 機器の CDP が、既定でアドバタイズを送る間隔は何秒か。", "60",
  "CDP の送信間隔は **60 秒**、ホールドタイムは 180 秒。"),
]),
"ip-connectivity": ("ip-conn", 2, [
 (1, ["routing", "administrative-distance"], "RIP のデフォルトのアドミニストレーティブディスタンス（AD）を答えよ。", "120",
  "RIP の AD は **120**。OSPF（110）や EIGRP 内部（90）より優先度が低い。"),
 (2, ["routing", "administrative-distance"], "eBGP のデフォルトの AD を答えよ。", "20",
  "eBGP の AD は **20**、iBGP は 200。"),
 (1, ["routing", "administrative-distance"], "直接接続ルートの AD を答えよ。", "0",
  "直接接続ルートの AD は **0** で、どのルーティングプロトコルより優先される。"),
 (2, ["ospf", "timer"], "OSPF のブロードキャスト型・ポイントツーポイント型ネットワークで、Hello 間隔の既定値は何秒か。", "10",
  "Hello 間隔は **10 秒**、Dead 間隔はその 4 倍の 40 秒。NBMA では 30 秒と 120 秒。"),
 (2, ["ospf", "timer"], "OSPF のブロードキャスト型ネットワークで、Dead 間隔の既定値は何秒か。", "40",
  "Dead 間隔は Hello 間隔（10 秒）の 4 倍の **40 秒**。"),
 (2, ["ospf", "cost"], "Cisco IOS で、OSPF のコスト計算に使う参照帯域幅の既定値は何 Mbps か。", "100",
  "既定の参照帯域幅は **100 Mbps**。コスト = 参照帯域幅 ÷ インターフェイスの帯域幅なので、100 Mbps 以上のリンクはどれもコスト 1 になる。"),
 (1, ["ospf", "area"], "OSPF のバックボーンエリアのエリア番号を答えよ。", "0",
  "バックボーンは **エリア 0**。ほかのエリアはエリア 0 につながっている必要がある。"),
 (2, ["ospf", "dr"], "OSPF のルータープライオリティの既定値を答えよ。", "1",
  "既定値は **1**。DR・BDR の選出ではプライオリティの大きいルーターが選ばれ、0 のルーターは選ばれない。"),
 (2, ["routing", "administrative-distance"], "EIGRP の外部ルートのデフォルトの AD を答えよ。", "170",
  "EIGRP は内部ルートが 90、**外部ルートが 170**。"),
 (1, ["routing", "host-route"], "1 台のホストだけを表すホストルートのプレフィックス長を答えよ。", "32",
  "32 ビットすべてがネットワーク部の **/32** は、アドレス 1 つだけを表す。"),
 (2, ["fhrp", "hsrp"], "HSRP のプライオリティの既定値を答えよ。", "100",
  "既定値は **100**。プライオリティの大きいルーターがアクティブになる。"),
 (2, ["fhrp", "hsrp"], "HSRP の Hello 間隔の既定値は何秒か。", "3",
  "Hello は **3 秒**、ホールドタイムは 10 秒。"),
]),
"ip-services": ("ip-svc", 1, [
 (1, ["ntp", "port"], "NTP が使う UDP のポート番号を答えよ。", "123",
  "NTP は UDP **123** 番。"),
 (1, ["snmp", "port"], "SNMP エージェントがマネージャーからの要求を受ける UDP のポート番号を答えよ。", "161",
  "要求は UDP **161** 番、トラップ（エージェントからの通知）は 162 番。"),
 (1, ["syslog", "port"], "syslog が使う UDP のポート番号を答えよ。", "514",
  "syslog は UDP **514** 番。"),
 (2, ["syslog", "severity"], "syslog の重大度で、warning（警告）のレベルの数値を答えよ。", "4",
  "0 emergency、1 alert、2 critical、3 error、**4 warning**、5 notice、6 informational、7 debugging。数値が小さいほど重大。"),
 (1, ["tftp", "port"], "TFTP が使う UDP のポート番号を答えよ。", "69",
  "TFTP は UDP **69** 番。認証のない簡単なファイル転送で、機器の設定や IOS イメージの転送に使う。"),
 (1, ["dhcp", "port"], "DHCP サーバーが使う UDP のポート番号を答えよ。", "67",
  "DHCP は **サーバーが 67 番**、クライアントが 68 番。"),
]),
"security-fundamentals": ("sec-fund", 2, [
 (1, ["acl"], "番号付きの標準 IPv4 ACL で使える番号のうち、1 から始まる範囲の最大値を答えよ。", "99",
  "標準 ACL は **1〜99**（と拡張範囲の 1300〜1999）。"),
 (1, ["acl"], "番号付きの拡張 IPv4 ACL で使える番号のうち、最初の範囲はいくつから始まるか。", "100",
  "拡張 ACL は **100**〜199（と拡張範囲の 2000〜2699）。"),
 (2, ["port-security"], "Cisco スイッチのポートセキュリティで、1 つのポートに許す MAC アドレス数の既定値を答えよ。", "1",
  "既定では **1 つ**。2 つ目の MAC アドレスを見つけると違反になる（既定の動作は shutdown）。"),
 (2, ["wireless", "wpa2"], "WPA2 パーソナルの事前共有鍵を ASCII のパスフレーズで設定するとき、最小の文字数を答えよ。", "8",
  "パスフレーズは **8〜63 文字**。"),
 (2, ["aaa", "radius"], "RADIUS の認証で使う UDP のポート番号（RFC 2865）を答えよ。", "1812",
  "RADIUS は認証が UDP **1812** 番、アカウンティングが 1813 番。"),
 (2, ["aaa", "tacacs"], "TACACS+ が使う TCP のポート番号を答えよ。", "49",
  "TACACS+ は TCP **49** 番。パケットの本体全体を暗号化する点が RADIUS と違う。"),
 (2, ["vpn", "ipsec"], "IPsec の鍵交換に使う IKE の UDP のポート番号を答えよ。", "500",
  "IKE は UDP **500** 番。NAT を越えるとき（NAT-T）は UDP 4500 番を使う。"),
]),
"automation-programmability": ("auto-prog", 1, [
 (1, ["rest", "http"], "HTTP のステータスコードで「404 Not Found」の数値を答えよ。", "404",
  "**404** は、要求したリソースが見つからないことを表す。4xx はクライアント側の誤り。"),
 (2, ["rest", "http"], "REST API でリソースの作成（POST）に成功したときに返す、「Created」を表す HTTP ステータスコードを答えよ。", "201",
  "**201 Created**。単に成功した場合は 200 OK。"),
 (2, ["netconf"], "NETCONF を SSH の上で使うときの既定の TCP ポート番号を答えよ。", "830",
  "NETCONF over SSH の既定のポートは **830**（RFC 6242）。"),
 (1, ["rest", "http"], "HTTP のステータスコードで、要求が成功したことを表す「OK」の数値を答えよ。", "200",
  "**200 OK**。2xx は成功を表す。"),
 (2, ["rest", "http"], "HTTP のステータスコードで、認証が必要または認証に失敗したことを表す「Unauthorized」の数値を答えよ。", "401",
  "**401 Unauthorized**。認証が通っても権限がない場合は 403 Forbidden。"),
]),
}

# 既存の手書き問題の ID と重ならないよう、続きの番号から振る
existing = json.load(open(os.path.join(ROOT, "NetTre/Resources/questions.json"), encoding="utf-8"))
next_no = {}
for q in existing:
    prefix, no = q["id"].rsplit("-", 1)
    next_no[prefix] = max(next_no.get(prefix, 1), int(no) + 1)

out = []
for domain, (prefix, _, items) in Q.items():
    for difficulty, tags, stem, answer, explanation in items:
        n = next_no.get(prefix, 1)
        next_no[prefix] = n + 1
        out.append({"id": f"{prefix}-{n:04d}", "domain": domain, "tags": tags, "difficulty": difficulty,
                    "stem": stem, "answer": answer, "explanation": explanation, "version": 1})

# QuestionRepository.validate と同じ検査
ids = [q["id"] for q in out] + [q["id"] for q in existing]
assert len(ids) == len(set(ids)), "ID が重なっている"
for q in out:
    assert re.fullmatch(r"(net-fund|net-access|ip-conn|ip-svc|sec-fund|auto-prog)-\d{4}", q["id"]), q["id"]
    assert re.fullmatch(r"[0-9.]*[0-9][0-9.]*", q["answer"]), q
stems = [q["stem"] for q in out + existing]
assert len(stems) == len(set(stems)), "同じ問題文がある"

os.makedirs(os.path.join(ROOT, "drafts"), exist_ok=True)
with open(os.path.join(ROOT, "drafts/questions_draft.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
    f.write("\n")

names = {"network-fundamentals": "ネットワークの基礎", "network-access": "ネットワークアクセス",
         "ip-connectivity": "IP 接続", "ip-services": "IP サービス",
         "security-fundamentals": "セキュリティの基礎", "automation-programmability": "自動化とプログラマビリティ"}
lines = ["# 手書き問題の下書き（50 問）— 確認用", "",
         "AI の下書き。**技術的に正しいかを人が確認してから** `NetTre/Resources/questions.json` に収録する（CLAUDE.md の決まり）。",
         "確認したら「確認」の列に ✓、直すものは「メモ」に書く。", ""]
for domain, (_, _, items) in Q.items():
    qs = [q for q in out if q["domain"] == domain]
    lines += [f"## {names[domain]}（{len(qs)} 問）", "", "| ID | 難易度 | 問題 | 正解 | 解説 | 確認 | メモ |", "|---|---|---|---|---|---|---|"]
    for q in qs:
        exp = q["explanation"].replace("|", "｜")
        lines.append(f"| {q['id']} | {q['difficulty']} | {q['stem']} | **{q['answer']}** | {exp} |  |  |")
    lines.append("")
with open(os.path.join(ROOT, "drafts/questions_draft_review.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(len(out), {d: len(v[2]) for d, v in Q.items()})
