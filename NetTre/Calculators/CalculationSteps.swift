import Foundation

/// 計算機の結果に添える解き方（FR-22、詳細設計 §6.9・§12.13）
enum CalculationSteps {
    static func cidr(_ s: Subnet) -> [String] {
        let p = s.prefix
        if p == 32 { return ["ホスト部がないので、アドレスそのものがネットワーク"] }
        if p == 0 { return ["すべてのビットがホスト部なので、ネットワークは 0.0.0.0"] }
        if p % 8 == 0 { return ["オクテットの境目なので、第 \(p / 8 + 1) オクテットから後ろを 0 にする"] }
        let index = p / 8
        let block = 256 >> (p % 8)
        let value = Int(s.address.octets[index])
        let k = value / block
        return [
            "区切りは第 \(index + 1) オクテット。ブロックサイズは \(block)",
            "\(value) は \(block) の \(k) 倍〜\(k + 1) 倍の間なので、ネットワークは .\(k * block)",
        ]
    }

    static func split(_ r: SplitResult, parent: Subnet) -> [String] {
        var lines: [String] = []
        if case let .count(n) = r.mode {
            if let rounded = r.roundedCount {
                lines.append("\(n) は 2 の累乗ではないので、\(rounded) 分割にする")
            }
            lines.append("/\(parent.prefix) から \(r.newPrefix - parent.prefix) ビット借りて /\(r.newPrefix)")
        } else if case let .hosts(h) = r.mode {
            lines.append("\(h) ＋ 2 以上の最小の 2 の累乗は \(UInt64(1) << UInt64(32 - r.newPrefix)) なので /\(r.newPrefix)")
        }
        lines.append("1 サブネットで使えるのは \(r.hostsPerSubnet) 台、全 \(r.totalCount) 件")
        return lines
    }

    static func vlsm(_ plan: VLSMPlan) -> [String] {
        let sizes = plan.allocations
            .map { "\($0.requirement.name) \($0.subnet.totalAddresses)" }
            .joined(separator: "・")
        return [
            "必要ホスト数の多い順に、必要数 ＋ 2 以上の最小の 2 の累乗のブロックを先頭から割り当てる",
            "ブロックの大きさ：\(sizes)",
        ]
    }

    static func summary(_ r: SummaryResult) -> [String] {
        [
            "最小のアドレスと最大のブロードキャストで、先頭の \(r.route.prefix) ビットが共通",
            "集約ルートは \(r.route.cidrString)",
        ]
    }
}
