import CoreGraphics
import Foundation

/// 数値の決まり（詳細設計 §2）。
enum Constants {
    static let sessionSize = 10
    static let generatedShareInMixed = 0.5
    static let easeInitial = 2.5
    static let easeMin = 1.3
    static let easeMax = 3.0
    static let generatedGraduationStreak = 2
    static let splitDisplayLimit = 256
    static let vlsmMaxRequirements = 50
    static let summaryMaxNetworks = 32
    static let extraRangesDisplayLimit = 256
    static let minTapHeight: CGFloat = 56
    static let copyToastDuration: TimeInterval = 1.5
    /// 自動生成の ID が重なったときに引き直す上限（詳細設計 §12.13）
    static let maxSeedRetries = 100
    /// 新しく作る自動生成問題の seed の範囲（詳細設計 §5.3）
    static let generatedSeedRange: ClosedRange<UInt64> = 1...999_999_999
}
