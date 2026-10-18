import Foundation

// MARK: - 分野・難易度

/// CCNA 200-301 の 6 分野（要件定義 §4.1）
enum Domain: String, Codable, CaseIterable, Identifiable {
    case networkFundamentals = "network-fundamentals"
    case networkAccess = "network-access"
    case ipConnectivity = "ip-connectivity"
    case ipServices = "ip-services"
    case securityFundamentals = "security-fundamentals"
    case automationProgrammability = "automation-programmability"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .networkFundamentals: "ネットワークの基礎"
        case .networkAccess: "ネットワークアクセス"
        case .ipConnectivity: "IP 接続"
        case .ipServices: "IP サービス"
        case .securityFundamentals: "セキュリティの基礎"
        case .automationProgrammability: "自動化とプログラマビリティ"
        }
    }

    /// 手書き問題の ID の略称（基本設計 §5.1）
    var idPrefix: String {
        switch self {
        case .networkFundamentals: "net-fund"
        case .networkAccess: "net-access"
        case .ipConnectivity: "ip-conn"
        case .ipServices: "ip-svc"
        case .securityFundamentals: "sec-fund"
        case .automationProgrammability: "auto-prog"
        }
    }
}

enum Difficulty: Int, Codable, CaseIterable, Comparable, Identifiable {
    case basic = 1, standard = 2, advanced = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .basic: "基礎"
        case .standard: "標準"
        case .advanced: "応用"
        }
    }

    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

// MARK: - 問題

/// 回答の入力欄に出すキーボード
enum AnswerKeyboard: Equatable {
    case number   // .numberPad
    case decimal  // .decimalPad

    /// 正解が数字だけなら数字、数字と「.」なら「.」付き
    init(for answer: String) {
        self = answer.contains(".") ? .decimal : .number
    }
}

/// 手書き問題と自動生成問題を同じ型で扱う。回答はすべて入力式（要件定義 FR-02）。
struct Question: Codable, Identifiable, Hashable {
    let id: String
    let domain: Domain
    let tags: [String]
    let difficulty: Difficulty
    let stem: String
    let answer: String          // 正解の文字列 1 つ
    let explanation: String     // Markdown
    let version: Int

    var isGenerated: Bool { id.hasPrefix("gen-subnet-") }
    var keyboard: AnswerKeyboard { AnswerKeyboard(for: answer) }

    func isCorrect(_ input: String) -> Bool {
        let normalized = AnswerNormalizer.normalize(input)
        return !normalized.isEmpty && normalized == AnswerNormalizer.normalize(answer)
    }
}
