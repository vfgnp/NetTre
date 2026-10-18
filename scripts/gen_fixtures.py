#!/usr/bin/env python3
"""照合用データを作る（詳細設計 §9、詳細テスト UT-SN-08・UT-CB-05・UT-RT-07）。

Python 標準の ipaddress の結果を正解として JSON に書き出す。seed を固定しているので、
何度実行しても同じデータになる。アプリには入れない（テストのバンドルにだけ入れる）。

使い方: python3 scripts/gen_fixtures.py
"""
import ipaddress
import json
import os
import random

SEED = 20261018
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "NetTreTests", "Fixtures")


def cidr_cases(rng, count):
    cases = []
    for _ in range(count):
        addr = rng.getrandbits(32)
        prefix = rng.randint(0, 32)
        net = ipaddress.ip_network((addr, prefix), strict=False)
        total = net.num_addresses
        if prefix <= 30:
            usable = total - 2
            first = net.network_address + 1
            last = net.broadcast_address - 1
        elif prefix == 31:
            usable = 2
            first = net.network_address
            last = net.broadcast_address
        else:
            usable = 1
            first = last = ipaddress.ip_address(addr)
        cases.append({
            "address": str(ipaddress.ip_address(addr)),
            "prefix": prefix,
            "network": str(net.network_address),
            "broadcast": str(net.broadcast_address),
            "mask": str(net.netmask),
            "wildcard": str(net.hostmask),
            "total": total,
            "usable": usable,
            "first": str(first),
            "last": str(last),
        })
    return cases


def block_cases(rng, count):
    cases = []
    for _ in range(count):
        a = rng.getrandbits(32)
        # 範囲の長さはいろいろな大きさになるように 2 のべきで散らす
        length = rng.getrandbits(rng.randint(0, 24))
        b = min(a + length, 2**32 - 1)
        blocks = [str(n) for n in ipaddress.summarize_address_range(
            ipaddress.ip_address(a), ipaddress.ip_address(b))]
        cases.append({"start": a, "end": b, "blocks": blocks})
    return cases


def summary_cases(rng, count):
    cases = []
    for _ in range(count):
        n = rng.randint(1, 6)
        base = rng.getrandbits(32)
        nets = []
        for _ in range(n):
            prefix = rng.randint(16, 30)
            spread = rng.getrandbits(rng.randint(0, 20))
            addr = (base + spread) % 2**32
            nets.append(ipaddress.ip_network((addr, prefix), strict=False))
        low = min(int(x.network_address) for x in nets)
        high = max(int(x.broadcast_address) for x in nets)
        p = 32 - (low ^ high).bit_length()
        route = ipaddress.ip_network((low & ((0xFFFFFFFF << (32 - p)) & 0xFFFFFFFF), p))
        # ルートから入力を除いた範囲
        intervals = sorted((int(x.network_address), int(x.broadcast_address)) for x in nets)
        merged = []
        for s, e in intervals:
            if merged and s <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], e)
            else:
                merged.append([s, e])
        extra = []
        cur = int(route.network_address)
        for s, e in merged:
            if s > cur:
                extra += [str(z) for z in ipaddress.summarize_address_range(
                    ipaddress.ip_address(cur), ipaddress.ip_address(s - 1))]
            cur = max(cur, e + 1)
        end = int(route.broadcast_address)
        if cur <= end:
            extra += [str(z) for z in ipaddress.summarize_address_range(
                ipaddress.ip_address(cur), ipaddress.ip_address(end))]
        cases.append({
            "networks": [str(x) for x in nets],
            "route": str(route),
            "extra": extra[:256],
            "extraTruncated": len(extra) > 256,
        })
    return cases


def main():
    rng = random.Random(SEED)
    os.makedirs(OUT_DIR, exist_ok=True)
    data = {
        "cidr_fixtures.json": cidr_cases(rng, 20000),
        "blocks_fixtures.json": block_cases(rng, 2000),
        "summary_fixtures.json": summary_cases(rng, 2000),
    }
    for name, cases in data.items():
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8") as f:
            json.dump(cases, f, ensure_ascii=False, separators=(",", ":"))
        print(f"{name}: {len(cases)} 件")


if __name__ == "__main__":
    main()
