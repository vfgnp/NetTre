import Foundation

/// アドレスの種別（詳細設計 §6.3。判定は上から順）
enum AddressKind: Equatable {
    case loopback, `private`, linkLocal, sharedAddress, multicast, reserved, global

    init(_ address: IPv4) {
        func within(_ network: IPv4, _ prefix: Int) -> Bool {
            address.value & IPv4.mask(prefix: prefix) == network.value
        }
        if within(IPv4(127, 0, 0, 0), 8) {
            self = .loopback
        } else if within(IPv4(10, 0, 0, 0), 8) || within(IPv4(172, 16, 0, 0), 12) || within(IPv4(192, 168, 0, 0), 16) {
            self = .private
        } else if within(IPv4(169, 254, 0, 0), 16) {
            self = .linkLocal
        } else if within(IPv4(100, 64, 0, 0), 10) {
            self = .sharedAddress
        } else if within(IPv4(224, 0, 0, 0), 4) {
            self = .multicast
        } else if within(IPv4(240, 0, 0, 0), 4) || within(IPv4(0, 0, 0, 0), 8) {
            self = .reserved
        } else {
            self = .global
        }
    }

    var displayName: String {
        switch self {
        case .loopback: "ループバック"
        case .private: "プライベート（RFC 1918）"
        case .linkLocal: "リンクローカル"
        case .sharedAddress: "共有アドレス（RFC 6598）"
        case .multicast: "マルチキャスト"
        case .reserved: "予約"
        case .global: "グローバル"
        }
    }
}

struct CIDRResult: Equatable {
    let subnet: Subnet
    let kind: AddressKind
    let steps: [String]
}

/// CIDR 計算（FR-17）
enum CIDRCalculator {
    static func calculate(address: IPv4, prefix: Int) -> CIDRResult {
        let subnet = Subnet(address: address, prefix: prefix)
        return CIDRResult(subnet: subnet, kind: AddressKind(address), steps: CalculationSteps.cidr(subnet))
    }
}
