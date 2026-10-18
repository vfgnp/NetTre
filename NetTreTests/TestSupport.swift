import Foundation
import SwiftData
@testable import NetTre

/// テストのバンドルを指すための型
final class BundleToken {}

enum TestSupport {
    static let calendar = AppEnvironment.tokyoCalendar

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi)) ?? Date()
    }

    /// 1 日目 = 2026-10-18 08:00 JST
    static let day1 = date(2026, 10, 18, 8)

    /// n 日目の 08:00
    static func day(_ n: Int, hour: Int = 8) -> Date { date(2026, 10, 17 + n, hour) }

    static func fixtureData(_ name: String) -> Data? {
        Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
    }

    static func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let data = fixtureData(name) else { throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// 05 §6 のテスト用の 20 問
    static var testQuestionsData: Data { fixtureData("questions_test") ?? Data() }

    static func testQuestions() -> [Question] {
        (try? JSONDecoder().decode([Question].self, from: testQuestionsData)) ?? []
    }

    static func repository(_ questions: [Question]? = nil) -> QuestionRepository {
        if let questions, let data = try? JSONEncoder().encode(questions) {
            return QuestionRepository(data: data, assertOnFailure: false)
        }
        return QuestionRepository(data: testQuestionsData, assertOnFailure: false)
    }

    static func handwritten(_ id: String, domain: Domain = .networkFundamentals, answer: String = "62",
                            version: Int = 1) -> Question {
        Question(id: id, domain: domain, tags: [], difficulty: .standard, stem: "問題 \(id) を答えよ。",
                 answer: answer, explanation: "解説", version: version)
    }

    static func generated(_ type: SubnetQuestionType = .hostCount, difficulty: Difficulty = .standard,
                          seed: UInt64 = 1) -> Question {
        SubnetQuestionGenerator.make(type: type, seed: seed, difficulty: difficulty)
    }

    static func ip(_ s: String) -> IPv4 {
        (try? IPv4InputParser.address(s).get()) ?? IPv4(0)
    }

    static func subnet(_ s: String) -> Subnet {
        let parts = s.split(separator: "/")
        return Subnet(address: ip(String(parts[0])), prefix: Int(parts[1]) ?? 0)
    }
}

/// メモリ上の学習履歴
@MainActor
final class InMemoryStore {
    let container: ModelContainer
    let store: ReviewStore

    init(save: (() throws -> Void)? = nil) {
        // テストごとに新しく作る
        container = try! ModelContainer(for: ReviewRecord.self, AnswerLog.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = ReviewStore(context: container.mainContext, calendar: TestSupport.calendar, save: save)
    }

    var context: ModelContext { container.mainContext }

    func records() -> [ReviewRecord] {
        (try? context.fetch(FetchDescriptor<ReviewRecord>(sortBy: [SortDescriptor(\.questionId)]))) ?? []
    }

    func logs() -> [AnswerLog] {
        (try? context.fetch(FetchDescriptor<AnswerLog>())) ?? []
    }

    /// 復習の記録を直接入れる
    func insertRecord(_ id: String, due: Date, domain: Domain = .networkFundamentals, generated: Bool? = nil) {
        let isGenerated = generated ?? id.hasPrefix("gen-subnet-")
        context.insert(ReviewRecord(questionId: id, questionVersion: 1, domainRaw: domain.rawValue,
                                    isGenerated: isGenerated, state: ReviewState(dueDate: due)))
        try? context.save()
    }

    func insertLog(_ id: String, correct: Bool, at date: Date, domain: Domain = .networkFundamentals) {
        context.insert(AnswerLog(questionId: id, domainRaw: domain.rawValue,
                                 isGenerated: id.hasPrefix("gen-subnet-"), isCorrect: correct, answeredAt: date))
        try? context.save()
    }
}

struct TestError: Error {}

/// #expect の中で rethrows の関数を直接呼ぶとマクロが展開できないため、値にしてから渡す
func check(_ value: Bool) -> Bool { value }

/// "net-fund-0001" のような ID の並び
func ids(_ prefix: String, _ range: ClosedRange<Int>) -> [String] {
    range.map { String(format: "%@-%04d", prefix, $0) }
}

/// recordAnswer だけ失敗し、ほかは本物に渡す
@MainActor
final class FailingRecorder: ReviewRecording {
    let base: ReviewRecording?
    private(set) var recordCalls = 0

    init(base: ReviewRecording? = nil) { self.base = base }

    func recordAnswer(question: Question, correct: Bool, now: Date) throws {
        recordCalls += 1
        throw TestError()
    }

    func dueRecords(in scope: SessionScope, now: Date) throws -> [ReviewRecord] {
        try base?.dueRecords(in: scope, now: now) ?? []
    }

    func answeredQuestionIds() throws -> Set<String> { try base?.answeredQuestionIds() ?? [] }
    func summary(now: Date) throws -> StatsSummary { try base?.summary(now: now) ?? .empty }
    func deleteAll() throws { try base?.deleteAll() }
}

/// 呼ばれた回数を数える記録
@MainActor
final class CountingRecorder: ReviewRecording {
    private(set) var recorded: [(id: String, correct: Bool)] = []

    func recordAnswer(question: Question, correct: Bool, now: Date) throws {
        recorded.append((question.id, correct))
    }

    func dueRecords(in scope: SessionScope, now: Date) throws -> [ReviewRecord] { [] }
    func answeredQuestionIds() throws -> Set<String> { [] }
    func summary(now: Date) throws -> StatsSummary { .empty }
    func deleteAll() throws {}
}

/// SeededRNG(seed: 7) の先頭 k 個を 2 回くり返してから続きを返す（05 §1）
struct RepeatingStubRNG: RandomNumberGenerator {
    private var queue: [UInt64]
    private var base: SeededRNG
    private(set) var calls = 0

    init(k: Int = 2) {
        var rng = SeededRNG(seed: 7)
        let head = (0..<k).map { _ in rng.next() }
        queue = head + head
        base = rng
    }

    mutating func next() -> UInt64 {
        calls += 1
        if !queue.isEmpty { return queue.removeFirst() }
        return base.next()
    }
}

/// SeededRNG(seed: 7) の先頭 k 個を返し続ける
struct CyclingStubRNG: RandomNumberGenerator {
    private let values: [UInt64]
    private var i = 0
    private(set) var calls = 0

    init(k: Int = 2) {
        var rng = SeededRNG(seed: 7)
        values = (0..<k).map { _ in rng.next() }
    }

    mutating func next() -> UInt64 {
        calls += 1
        defer { i = (i + 1) % values.count }
        return values[i]
    }
}
