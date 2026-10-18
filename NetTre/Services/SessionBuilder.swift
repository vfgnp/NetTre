import Foundation

/// 1 回の学習の問題を組み立てる（詳細設計 §5.3・§12.4・§12.13）
struct SessionBuilder {
    struct Session {
        let questions: [Question]
        /// 復習として出す問題の ID（「復習」の印に使う）
        let reviewIds: Set<String>
    }

    @MainActor
    func build(scope: SessionScope, now: Date, calendar: Calendar, store: some ReviewRecording,
               repository: QuestionRepository, rng: inout some RandomNumberGenerator) throws -> [Question] {
        try buildSession(scope: scope, now: now, calendar: calendar, store: store,
                         repository: repository, rng: &rng).questions
    }

    @MainActor
    func buildSession(scope: SessionScope, now: Date, calendar: Calendar, store: some ReviewRecording,
                      repository: QuestionRepository, rng: inout some RandomNumberGenerator) throws -> Session {
        let size = Constants.sessionSize

        // 1. 復習（問題がない ID は飛ばす）
        var questions: [Question] = Array(try store.dueRecords(in: scope, now: now)
            .lazy
            .compactMap { repository.question(id: $0.questionId) }
            .prefix(size))
        let reviewIds = Set(questions.map(\.id))
        var usedIds = reviewIds

        // 2. 新しい問題で埋める
        let remaining = size - questions.count
        guard remaining > 0 else { return Session(questions: questions, reviewIds: reviewIds) }
        let answered = try store.answeredQuestionIds()
        func unanswered(_ filter: (Question) -> Bool) -> [Question] {
            repository.handwritten.filter { filter($0) && !answered.contains($0.id) && !usedIds.contains($0.id) }
        }

        switch scope {
        case .mixed:
            let generatedCount = Int(Double(remaining) * Constants.generatedShareInMixed)
            let handwritten = Array(unanswered { _ in true }.prefix(remaining - generatedCount))
            questions += handwritten
            usedIds.formUnion(handwritten.map(\.id))
            questions += generated(count: size - questions.count, difficulty: .standard, used: &usedIds, rng: &rng)
        case let .domain(domain):
            questions += unanswered { $0.domain == domain }.prefix(remaining)
        case let .subnetDrill(level):
            questions += generated(count: remaining, difficulty: level, used: &usedIds, rng: &rng)
        }
        return Session(questions: questions, reviewIds: reviewIds)
    }

    /// 自動生成問題を作る。ID が重なったら seed を引き直し、上限を超えたらその 1 問は入れない
    private func generated(count: Int, difficulty: Difficulty, used: inout Set<String>,
                           rng: inout some RandomNumberGenerator) -> [Question] {
        var result: [Question] = []
        let types = SubnetQuestionType.allCases
        for _ in 0..<max(count, 0) {
            for _ in 0...Constants.maxSeedRetries {
                let type = types[Int.random(in: 0..<types.count, using: &rng)]
                let seed = UInt64.random(in: Constants.generatedSeedRange, using: &rng)
                let id = SubnetQuestionGenerator.makeId(type: type, difficulty: difficulty, seed: seed)
                if used.insert(id).inserted {
                    result.append(SubnetQuestionGenerator.make(type: type, seed: seed, difficulty: difficulty))
                    break
                }
            }
        }
        return result
    }
}
