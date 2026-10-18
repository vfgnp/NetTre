import Foundation
import SwiftData

/// 問題ごとの復習の状態（基本設計 §5.2）
@Model
final class ReviewRecord {
    @Attribute(.unique) var questionId: String
    var questionVersion: Int
    var domainRaw: String
    var isGenerated: Bool
    var interval: Int
    var ease: Double
    var streak: Int
    var dueDate: Date

    init(questionId: String, questionVersion: Int, domainRaw: String, isGenerated: Bool, state: ReviewState) {
        self.questionId = questionId
        self.questionVersion = questionVersion
        self.domainRaw = domainRaw
        self.isGenerated = isGenerated
        self.interval = state.interval
        self.ease = state.ease
        self.streak = state.streak
        self.dueDate = state.dueDate
    }

    var state: ReviewState {
        get { ReviewState(interval: interval, ease: ease, streak: streak, dueDate: dueDate) }
        set {
            interval = newValue.interval
            ease = newValue.ease
            streak = newValue.streak
            dueDate = newValue.dueDate
        }
    }
}

/// 回答ごとの記録（成績の集計に使う）
@Model
final class AnswerLog {
    var questionId: String
    var domainRaw: String
    var isGenerated: Bool
    var isCorrect: Bool
    var answeredAt: Date

    init(questionId: String, domainRaw: String, isGenerated: Bool, isCorrect: Bool, answeredAt: Date) {
        self.questionId = questionId
        self.domainRaw = domainRaw
        self.isGenerated = isGenerated
        self.isCorrect = isCorrect
        self.answeredAt = answeredAt
    }
}
