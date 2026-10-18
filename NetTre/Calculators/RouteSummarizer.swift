import Foundation

struct SummaryResult: Equatable {
    let route: Subnet
    let extraRanges: [Subnet]
    let extraTruncated: Bool
    let normalizedHostBits: Bool
}

enum SummaryError: Error, Equatable {
    case empty, tooMany

    var message: String {
        switch self {
        case .empty: "ネットワークを入力してください"
        case .tooMany: "ネットワークは \(Constants.summaryMaxNetworks) 件までです"
        }
    }
}

/// 経路集約（FR-20、詳細設計 §6.7）
enum RouteSummarizer {
    static func summarize(_ networks: [Subnet]) -> Result<SummaryResult, SummaryError> {
        guard !networks.isEmpty else { return .failure(.empty) }
        guard networks.count <= Constants.summaryMaxNetworks else { return .failure(.tooMany) }
        let normalized = networks.map(\.normalized)
        let hostBits = zip(networks, normalized).contains { $0.address != $1.address }

        let low = normalized.map(\.network.value).min() ?? 0
        let high = normalized.map(\.broadcast.value).max() ?? 0
        let prefix = (low ^ high).leadingZeroBitCount
        let route = Subnet(address: IPv4(low & IPv4.mask(prefix: prefix)), prefix: prefix)

        // 入力の範囲をまとめ、ルートから除いた隙間を CIDR に分ける
        let intervals = normalized
            .map { (UInt64($0.network.value), UInt64($0.broadcast.value)) }
            .sorted { $0.0 < $1.0 }
        var merged: [(UInt64, UInt64)] = []
        for (s, e) in intervals {
            if let lastPair = merged.last, s <= lastPair.1 + 1 {
                merged[merged.count - 1].1 = max(lastPair.1, e)
            } else {
                merged.append((s, e))
            }
        }
        var extra: [Subnet] = []
        var truncated = false
        var cursor = UInt64(route.network.value)
        let routeEnd = UInt64(route.broadcast.value)
        func addGap(_ from: UInt64, _ to: UInt64) {
            guard !truncated, from <= to else { return }
            let remaining = Constants.extraRangesDisplayLimit - extra.count
            let part = CIDRBlocks.blocks(from: from, to: to, limit: remaining)
            extra += part.blocks
            if part.truncated { truncated = true }
        }
        for (s, e) in merged {
            if s > cursor { addGap(cursor, s - 1) }
            cursor = max(cursor, e + 1)
        }
        if cursor <= routeEnd { addGap(cursor, routeEnd) }
        return .success(SummaryResult(route: route, extraRanges: extra, extraTruncated: truncated,
                                      normalizedHostBits: hostBits))
    }
}
