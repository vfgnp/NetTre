import Foundation

// MARK: - IPv4 アドレス

struct IPv4: Hashable, Comparable, CustomStringConvertible {
    let value: UInt32

    init(_ value: UInt32) { self.value = value }

    init(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) {
        value = UInt32(a) << 24 | UInt32(b) << 16 | UInt32(c) << 8 | UInt32(d)
    }

    var octets: [UInt8] {
        [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
    }

    var description: String {
        octets.map(String.init).joined(separator: ".")
    }

    /// "11000000.10101000.00001010.01001101"
    var binaryString: String {
        octets.map { octet in
            let bits = String(octet, radix: 2)
            return String(repeating: "0", count: 8 - bits.count) + bits
        }.joined(separator: ".")
    }

    /// "C0.A8.0A.4D"
    var hexString: String {
        octets.map { String(format: "%02X", $0) }.joined(separator: ".")
    }

    static func < (l: IPv4, r: IPv4) -> Bool { l.value < r.value }

    /// プレフィックス長からマスクを作る（0...32）
    static func mask(prefix: Int) -> UInt32 {
        prefix <= 0 ? 0 : (prefix >= 32 ? UInt32.max : UInt32.max << UInt32(32 - prefix))
    }
}

// MARK: - サブネット（/0〜/32）

struct Subnet: Hashable {
    /// 入力されたアドレス（ホスト部を含む）
    let address: IPv4
    let prefix: Int

    init(address: IPv4, prefix: Int) {
        self.address = address
        self.prefix = min(max(prefix, 0), 32)
    }

    var mask: IPv4 { IPv4(IPv4.mask(prefix: prefix)) }
    var wildcard: IPv4 { IPv4(~mask.value) }
    var network: IPv4 { IPv4(address.value & mask.value) }
    var broadcast: IPv4 { IPv4(network.value | wildcard.value) }

    /// アドレスの総数 2^(32-p)
    var totalAddresses: UInt64 { UInt64(1) << UInt64(32 - prefix) }

    /// 使えるホスト数。/31 は 2（RFC 3021）、/32 は 1
    var usableHosts: UInt64 {
        switch prefix {
        case 32: 1
        case 31: 2
        default: totalAddresses - 2
        }
    }

    var firstHost: IPv4 {
        switch prefix {
        case 32: address
        case 31: network
        default: IPv4(network.value + 1)
        }
    }

    var lastHost: IPv4 {
        switch prefix {
        case 32: address
        case 31: broadcast
        default: IPv4(broadcast.value - 1)
        }
    }

    /// "192.168.10.64/26"（ネットワークアドレスを使う）
    var cidrString: String { "\(network)/\(prefix)" }

    /// ネットワークアドレスにそろえたもの
    var normalized: Subnet { Subnet(address: network, prefix: prefix) }
}

// MARK: - 再現できる乱数（SplitMix64）

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
