import Foundation

/// 回答と計算機の入力を同じ順で整える（基本設計 §6.3、詳細設計 §3.2）
enum AnswerNormalizer {
    static func normalize(_ s: String) -> String {
        // 1. 全角を半角に
        var t = s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
        // 2. 地域設定で小数点キーが「,」になる端末のため「,」を「.」に
        t = t.replacingOccurrences(of: ",", with: ".")
        // 3. 空白を除く（全角の空白も含む）
        t = String(t.filter { !$0.isWhitespace })
        // 4. 小文字にする
        return t.lowercased()
    }
}
