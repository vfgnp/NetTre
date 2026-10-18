import Foundation

/// 間隔反復（SM-2 の簡略版）の状態（詳細設計 §3.3）
struct ReviewState: Codable, Equatable {
    var interval: Int = 0
    var ease: Double = Constants.easeInitial
    var streak: Int = 0
    var dueDate: Date

    init(dueDate: Date) {
        self.dueDate = dueDate
    }

    init(interval: Int, ease: Double, streak: Int, dueDate: Date) {
        self.interval = interval
        self.ease = ease
        self.streak = streak
        self.dueDate = dueDate
    }

    /// 回答を反映する。正解は今の ease で interval を先に計算してから ease を上げる（§12.13）。
    mutating func record(correct: Bool, now: Date, calendar: Calendar) {
        if correct {
            streak += 1
            switch streak {
            case 1: interval = 1
            case 2: interval = 3
            default: interval = Int((Double(interval) * ease).rounded())
            }
            ease = min(ease + 0.1, Constants.easeMax)
        } else {
            streak = 0
            interval = 1
            ease = max(ease - 0.2, Constants.easeMin)
        }
        // 次に出す日は日付単位（D2）
        let today = calendar.startOfDay(for: now)
        dueDate = calendar.date(byAdding: .day, value: interval, to: today) ?? today
    }
}
