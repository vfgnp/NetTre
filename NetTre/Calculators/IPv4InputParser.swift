import Foundation

/// 計算機の入力の誤り（詳細設計 §6.2・§12.8・§12.13）
enum InputError: Error, Equatable {
    case empty
    case octetCount(Int)
    case octetRange(index: Int, value: Int)
    case notNumber(index: Int)
    case prefixRange(Int)
    case maskNotContiguous
    case invalidPrefix
    case invalidRadix

    var message: String {
        switch self {
        case .empty:
            "入力してください"
        case .octetCount:
            "4 つの数をピリオドで区切って入力してください"
        case let .octetRange(index, value):
            value == Int.max
                ? "第\(index)オクテットが大きすぎます（0〜255）"
                : "第\(index)オクテットが \(value) です（0〜255）"
        case let .notNumber(index):
            "第\(index)オクテットが数字ではありません"
        case .prefixRange:
            "プレフィックス長は 0〜32 です"
        case .maskNotContiguous:
            "マスクの 1 が連続していません"
        case .invalidPrefix:
            "プレフィックス長は 0〜32 の数かマスクで入力してください"
        case .invalidRadix:
            "10 進・2 進・16 進のどれかで入力してください"
        }
    }
}

enum IPv4InputParser {
    /// "192.168.10.77" を読む。全角・「,」・空白は先に整える。
    static func address(_ s: String) -> Result<IPv4, InputError> {
        let t = AnswerNormalizer.normalize(s)
        guard !t.isEmpty else { return .failure(.empty) }
        let parts = t.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return .failure(.octetCount(parts.count)) }
        var value: UInt32 = 0
        for (i, part) in parts.enumerated() {
            let index = i + 1
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                return .failure(.notNumber(index: index))
            }
            // 先頭の 0 はいくつ付いてもよい。Int に収まらなければ Int.max
            let number = Int(part) ?? Int.max
            guard number <= 255 else { return .failure(.octetRange(index: index, value: number)) }
            value = value << 8 | UInt32(number)
        }
        return .success(IPv4(value))
    }

    /// "26" または "255.255.255.192" をプレフィックス長として読む
    static func prefixOrMask(_ s: String) -> Result<Int, InputError> {
        let t = AnswerNormalizer.normalize(s)
        guard !t.isEmpty else { return .failure(.empty) }
        if t.contains(".") {
            switch address(t) {
            case let .failure(error):
                return .failure(error)
            case let .success(mask):
                let wildcard = ~mask.value
                // ワイルドカード + 1 が 2 の累乗（または 0）なら 1 が連続している
                guard wildcard & (wildcard &+ 1) == 0 else { return .failure(.maskNotContiguous) }
                return .success(mask.value.nonzeroBitCount)
            }
        }
        guard t.allSatisfy({ $0.isASCII && $0.isNumber }) else { return .failure(.invalidPrefix) }
        let number = Int(t) ?? Int.max
        guard (0...32).contains(number) else { return .failure(.prefixRange(number)) }
        return .success(number)
    }

    /// 貼り付けた "a.b.c.d/n" や "a.b.c.d m.m.m.m" を 2 つに分ける。分けられなければ nil。
    static func splitPasted(_ s: String) -> (address: String, prefix: String)? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let slash = trimmed.firstIndex(where: { $0 == "/" || $0 == "／" }) {
            let a = trimmed[..<slash].trimmingCharacters(in: .whitespaces)
            let p = trimmed[trimmed.index(after: slash)...].trimmingCharacters(in: .whitespaces)
            guard !a.isEmpty, !p.isEmpty else { return nil }
            return (a, p)
        }
        let pieces = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard pieces.count == 2 else { return nil }
        return (pieces[0], pieces[1])
    }
}
