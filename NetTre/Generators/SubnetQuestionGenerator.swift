import Foundation

// MARK: - 出題パターン

enum SubnetQuestionType: String, CaseIterable {
    case networkAddress, broadcastAddress, hostCount, maskFromPrefix, lastHost
}

/// サブネット計算の問題を seed から作る（詳細設計 §5.1・§12.5）。
/// 同じ種類・難易度・seed なら必ず同じ問題になるので、履歴には ID だけを残せばよい。
enum SubnetQuestionGenerator {
    static let idPrefix = "gen-subnet-"

    static func makeId(type: SubnetQuestionType, difficulty: Difficulty, seed: UInt64) -> String {
        "\(idPrefix)\(type.rawValue)-\(difficulty.rawValue)-\(seed)"
    }

    static func make(type: SubnetQuestionType, seed: UInt64, difficulty: Difficulty) -> Question {
        let subnet = subnet(seed: seed, difficulty: difficulty)
        let cidr = "\(subnet.address)/\(subnet.prefix)"
        let tip = "暗算のコツ：" + CalculationSteps.cidr(subnet).joined(separator: "。")

        let stem: String
        let answer: String
        let explanation: String
        switch type {
        case .networkAddress:
            stem = "\(cidr) が所属するネットワークアドレスを答えよ。"
            answer = subnet.network.description
            explanation = """
            /\(subnet.prefix) のサブネットマスクは \(subnet.mask)。
            アドレスとマスクの論理積（AND）を取ると **\(subnet.network)** になる。

            \(tip)
            """
        case .broadcastAddress:
            stem = "\(cidr) のブロードキャストアドレスを答えよ。"
            answer = subnet.broadcast.description
            explanation = """
            ネットワークアドレスは \(subnet.network)。
            ホスト部のビットをすべて 1 にすると **\(subnet.broadcast)** になる。

            \(tip)
            """
        case .hostCount:
            let hostBits = 32 - subnet.prefix
            stem = "/\(subnet.prefix) のサブネットで割り当て可能なホスト数を答えよ。"
            answer = String(subnet.usableHosts)
            explanation = """
            ホスト部は 32 − \(subnet.prefix) = \(hostBits) ビット。
            2^\(hostBits) − 2（ネットワークアドレスとブロードキャストアドレスを除く）= **\(subnet.usableHosts)**。
            """
        case .maskFromPrefix:
            stem = "/\(subnet.prefix) をドット 10 進表記のサブネットマスクで表したものを答えよ。"
            answer = subnet.mask.description
            explanation = "先頭から \(subnet.prefix) ビットを 1 にすると **\(subnet.mask)** になる。"
        case .lastHost:
            stem = "\(cidr) のサブネットで、割り当て可能な最後のホストアドレスを答えよ。"
            answer = subnet.lastHost.description
            explanation = """
            ブロードキャストアドレス \(subnet.broadcast) の 1 つ前、**\(subnet.lastHost)** が最後のホストアドレス。

            \(tip)
            """
        }

        return Question(
            id: makeId(type: type, difficulty: difficulty, seed: seed),
            domain: .networkFundamentals,
            tags: ["subnet", "ipv4", type.rawValue],
            difficulty: difficulty,
            stem: stem,
            answer: answer,
            explanation: explanation,
            version: 1
        )
    }

    /// ID を分解する。形式が違えば nil（§12.13）
    static func parse(_ id: String) -> (type: SubnetQuestionType, difficulty: Difficulty, seed: UInt64)? {
        guard id.hasPrefix(idPrefix) else { return nil }
        let parts = id.dropFirst(idPrefix.count).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let type = SubnetQuestionType(rawValue: String(parts[0])),
              parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let level = Int(parts[1]), let difficulty = Difficulty(rawValue: level),
              !parts[2].isEmpty, parts[2].allSatisfy({ $0.isASCII && $0.isNumber }),
              let seed = UInt64(parts[2])
        else { return nil }
        return (type, difficulty, seed)
    }

    static func question(fromId id: String) -> Question? {
        parse(id).map { make(type: $0.type, seed: $0.seed, difficulty: $0.difficulty) }
    }

    /// 問題の元になったアドレスとプレフィックス長（FR-23 で計算機に渡す）
    static func subnet(fromId id: String) -> Subnet? {
        parse(id).map { subnet(seed: $0.seed, difficulty: $0.difficulty) }
    }

    // MARK: 内部処理

    private static func subnet(seed: UInt64, difficulty: Difficulty) -> Subnet {
        var rng = SeededRNG(seed: seed)
        // 難易度でプレフィックス長の範囲を変える（基礎はオクテットの境目）
        let prefix: Int
        switch difficulty {
        case .basic: prefix = [8, 16, 24][Int.random(in: 0..<3, using: &rng)]
        case .standard: prefix = Int.random(in: 24...30, using: &rng)
        case .advanced: prefix = Int.random(in: 17...30, using: &rng)
        }
        // プライベートアドレスの帯から選ぶ
        let address: IPv4
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: address = IPv4(10, octet(&rng), octet(&rng), octet(&rng))
        case 1: address = IPv4(172, UInt8.random(in: 16...31, using: &rng), octet(&rng), octet(&rng))
        default: address = IPv4(192, 168, octet(&rng), octet(&rng))
        }
        return Subnet(address: address, prefix: prefix)
    }

    private static func octet(_ rng: inout SeededRNG) -> UInt8 { UInt8.random(in: 1...254, using: &rng) }
}
