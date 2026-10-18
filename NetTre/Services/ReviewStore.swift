import Foundation
import SwiftData

/// 出題範囲（詳細設計 §5.3）
enum SessionScope: Hashable {
    case mixed
    case domain(Domain)
    case subnetDrill(Difficulty)
}

/// 成績の型（詳細設計 §12.6）
struct CategoryStats: Equatable {
    let answered: Int
    let correct: Int

    static let zero = CategoryStats(answered: 0, correct: 0)

    /// 0 件は nil（「まだ回答していません」）
    var rate: Double? { answered == 0 ? nil : Double(correct) / Double(answered) }

    /// 画面の %（四捨五入）
    var percentText: String? { rate.map { "\(Int(($0 * 100).rounded()))%" } }
}

struct StatsSummary: Equatable {
    let total: CategoryStats
    let subnet: CategoryStats
    let byDomain: [Domain: CategoryStats]
    let dueToday: Int
    let answeredToday: Int

    static let empty = StatsSummary(total: .zero, subnet: .zero, byDomain: [:], dueToday: 0, answeredToday: 0)
}

/// 学習履歴の境界（詳細設計 §12.2）。テストは保存に失敗する実装を渡せる。
@MainActor
protocol ReviewRecording: AnyObject {
    func recordAnswer(question: Question, correct: Bool, now: Date) throws
    func dueRecords(in scope: SessionScope, now: Date) throws -> [ReviewRecord]
    func answeredQuestionIds() throws -> Set<String>
    func summary(now: Date) throws -> StatsSummary
    func deleteAll() throws
}

/// SwiftData に学習履歴を保存する（詳細設計 §4.1）
@MainActor
final class ReviewStore: ReviewRecording {
    private let context: ModelContext
    private let calendar: Calendar
    private let save: () throws -> Void

    init(context: ModelContext, calendar: Calendar, save: (() throws -> Void)? = nil) {
        self.context = context
        self.calendar = calendar
        self.save = save ?? { try context.save() }
    }

    func recordAnswer(question: Question, correct: Bool, now: Date) throws {
        context.insert(AnswerLog(questionId: question.id, domainRaw: question.domain.rawValue,
                                 isGenerated: question.isGenerated, isCorrect: correct, answeredAt: now))
        let id = question.id
        let existing = try context.fetch(FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.questionId == id })).first

        if let record = existing {
            var state = record.state
            state.record(correct: correct, now: now, calendar: calendar)
            record.state = state
            record.questionVersion = question.version
            // 自動生成問題は 2 回続けて正解したら記録を消す（D3）
            if question.isGenerated, correct, state.streak >= Constants.generatedGraduationStreak {
                context.delete(record)
            }
        } else if !question.isGenerated || !correct {
            var state = ReviewState(dueDate: now)
            state.record(correct: correct, now: now, calendar: calendar)
            context.insert(ReviewRecord(questionId: id, questionVersion: question.version,
                                        domainRaw: question.domain.rawValue,
                                        isGenerated: question.isGenerated, state: state))
        }

        do {
            try save()
        } catch {
            // 保存できなかった回答は成績にも復習にも入れない（§12.11）
            context.rollback()
            throw error
        }
    }

    func dueRecords(in scope: SessionScope, now: Date) throws -> [ReviewRecord] {
        let descriptor = FetchDescriptor<ReviewRecord>(
            predicate: #Predicate { $0.dueDate <= now },
            sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.questionId)]
        )
        return try context.fetch(descriptor).filter { record in
            switch scope {
            case .mixed:
                true
            case let .domain(domain):
                !record.isGenerated && record.domainRaw == domain.rawValue
            case let .subnetDrill(level):
                record.isGenerated && SubnetQuestionGenerator.parse(record.questionId)?.difficulty == level
            }
        }
    }

    func answeredQuestionIds() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<AnswerLog>()).map(\.questionId))
    }

    func summary(now: Date) throws -> StatsSummary {
        let logs = try context.fetch(FetchDescriptor<AnswerLog>())
        func stats(_ items: [AnswerLog]) -> CategoryStats {
            CategoryStats(answered: items.count, correct: items.filter(\.isCorrect).count)
        }
        var byDomain: [Domain: CategoryStats] = [:]
        let handwritten = logs.filter { !$0.isGenerated }
        for domain in Domain.allCases {
            byDomain[domain] = stats(handwritten.filter { $0.domainRaw == domain.rawValue })
        }
        let startOfToday = calendar.startOfDay(for: now)
        let dueCount = try context.fetchCount(FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.dueDate <= now }))
        return StatsSummary(
            total: stats(logs),
            subnet: stats(logs.filter(\.isGenerated)),
            byDomain: byDomain,
            dueToday: dueCount,
            answeredToday: logs.filter { $0.answeredAt >= startOfToday }.count
        )
    }

    func deleteAll() throws {
        try context.delete(model: ReviewRecord.self)
        try context.delete(model: AnswerLog.self)
        try save()
    }
}
