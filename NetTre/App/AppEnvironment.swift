import Foundation

/// 時刻・暦・乱数を外から渡すための入れ物（詳細設計 §12.1）。
struct AppEnvironment {
    var now: () -> Date = { Date() }
    var calendar: Calendar = .current
    var makeRNG: () -> any RandomNumberGenerator = { SystemRandomNumberGenerator() }

    /// テストと UI テストで使う暦（Asia/Tokyo のグレゴリオ暦）
    static var tokyoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return calendar
    }
}
