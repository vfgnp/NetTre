import Foundation

enum SplitMode: Equatable {
    case count(Int)
    case hosts(Int)
}

struct SplitResult: Equatable {
    let newPrefix: Int
    let hostsPerSubnet: UInt64
    let totalCount: UInt64
    /// 先頭 splitDisplayLimit 件まで（D6）
    let subnets: [Subnet]
    /// 2 の累乗でない分割数を切り上げた数（5 → 8）
    let roundedCount: Int?
    let mode: SplitMode
}

enum SplitError: Error, Equatable {
    case tooSmall, invalidNumber, exceedsParent

    var message: String {
        switch self {
        case .tooSmall: "これ以上は分けられません（/32 を超えます）"
        case .invalidNumber: "1 以上の数を入力してください"
        case .exceedsParent: "親のネットワークより大きいブロックが必要です"
        }
    }
}

/// サブネット分割（FR-18、詳細設計 §6.5）
enum SubnetSplitter {
    static func split(_ parent: Subnet, mode: SplitMode) -> Result<SplitResult, SplitError> {
        let newPrefix: Int
        var rounded: Int?
        switch mode {
        case let .count(n):
            guard n >= 1 else { return .failure(.invalidNumber) }
            var bits = 0
            while (UInt64(1) << UInt64(bits)) < UInt64(n) {
                bits += 1
                if parent.prefix + bits > 32 { return .failure(.tooSmall) }
            }
            newPrefix = parent.prefix + bits
            let power = Int(UInt64(1) << UInt64(bits))
            if power != n { rounded = power }
        case let .hosts(h):
            guard h >= 1 else { return .failure(.invalidNumber) }
            let need = UInt64(h) + 2
            var size: UInt64 = 1
            while size < need { size <<= 1 }
            guard size <= (UInt64(1) << 32) else { return .failure(.exceedsParent) }
            let prefix = 32 - size.trailingZeroBitCount
            guard prefix >= parent.prefix else { return .failure(.exceedsParent) }
            newPrefix = prefix
        }
        let total = UInt64(1) << UInt64(newPrefix - parent.prefix)
        let blockSize = UInt64(1) << UInt64(32 - newPrefix)
        let start = UInt64(parent.network.value)
        let shown = min(total, UInt64(Constants.splitDisplayLimit))
        let subnets = (0..<shown).map { i in
            Subnet(address: IPv4(UInt32(start + i * blockSize)), prefix: newPrefix)
        }
        let hosts = Subnet(address: parent.network, prefix: newPrefix).usableHosts
        return .success(SplitResult(newPrefix: newPrefix, hostsPerSubnet: hosts, totalCount: total,
                                    subnets: subnets, roundedCount: rounded, mode: mode))
    }
}
