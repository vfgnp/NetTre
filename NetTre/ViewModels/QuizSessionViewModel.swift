import Foundation
import Observation

/// 出題（S-03）と結果（S-04）の状態（詳細設計 §7.2・§12.7）
@Observable @MainActor
final class QuizSessionViewModel: Identifiable {
    enum Phase: Equatable {
        case empty
        case answering
        case answered(correct: Bool)
        case finished
    }

    struct Outcome: Identifiable {
        let question: Question
        let correct: Bool
        let input: String
        var id: String { question.id }
    }

    let id = UUID()
    let scope: SessionScope
    private(set) var questions: [Question]
    private(set) var reviewIds: Set<String>
    private(set) var index = 0
    var input = ""
    private(set) var phase: Phase
    private(set) var outcomes: [Outcome] = []
    var saveFailed = false
    private(set) var shouldDismiss = false

    private let store: any ReviewRecording
    private let now: () -> Date

    init(questions: [Question], reviewIds: Set<String> = [], scope: SessionScope,
         store: any ReviewRecording, now: @escaping () -> Date) {
        self.questions = questions
        self.reviewIds = reviewIds
        self.scope = scope
        self.store = store
        self.now = now
        phase = questions.isEmpty ? .empty : .answering
    }

    var current: Question? { questions.indices.contains(index) ? questions[index] : nil }
    var isReview: Bool { current.map { reviewIds.contains($0.id) } ?? false }
    var progressText: String { "\(min(index + 1, questions.count)) / \(questions.count)" }
    var progress: Double { questions.isEmpty ? 0 : Double(index + 1) / Double(questions.count) }
    var isLast: Bool { index >= questions.count - 1 }
    var canSubmit: Bool { phase == .answering && !AnswerNormalizer.normalize(input).isEmpty }
    var correctCount: Int { outcomes.filter(\.correct).count }
    var wrongOutcomes: [Outcome] { outcomes.filter { !$0.correct } }
    var lastOutcome: Outcome? { outcomes.last }

    func submit() {
        guard canSubmit, let question = current else { return }
        let correct = question.isCorrect(input)
        outcomes.append(Outcome(question: question, correct: correct, input: input))
        do {
            try store.recordAnswer(question: question, correct: correct, now: now())
        } catch {
            // 保存できなくても学習は続ける（§8）
            saveFailed = true
        }
        phase = .answered(correct: correct)
    }

    func next() {
        guard case .answered = phase else { return }
        if isLast {
            phase = .finished
        } else {
            index += 1
            input = ""
            phase = .answering
        }
    }

    func quit() {
        if outcomes.isEmpty {
            shouldDismiss = true
        } else {
            phase = .finished
        }
    }
}
