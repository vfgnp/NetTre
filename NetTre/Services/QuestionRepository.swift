import Foundation
import os

struct ValidationIssue: Equatable {
    enum Kind: Equatable { case duplicateId, invalidIdFormat, invalidAnswer }
    let kind: Kind
    let id: String
}

/// 手書き問題を読み、ID から問題を引く（詳細設計 §5.2・§12.3）
final class QuestionRepository {
    private static let logger = Logger(subsystem: "jp.nettre.app", category: "QuestionRepository")

    /// ファイルの並び順
    let handwritten: [Question]
    private(set) var loadFailed = false
    private(set) var issues: [ValidationIssue] = []
    private let byId: [String: Question]

    init(data: Data?, assertOnFailure: Bool = true) {
        var loaded: [Question] = []
        var failed = false
        if let data, let decoded = try? JSONDecoder().decode([Question].self, from: data) {
            loaded = decoded
        } else {
            failed = true
        }
        let issues = Self.validate(loaded)
        // 誤りのある問題は外し、ID が重なったら先の 1 問だけ残す（§12.13）
        let broken = Set(issues.filter { $0.kind != .duplicateId }.map(\.id))
        var seen = Set<String>()
        let kept = loaded.filter { !broken.contains($0.id) && seen.insert($0.id).inserted }

        handwritten = kept
        loadFailed = failed
        self.issues = issues
        byId = Dictionary(kept.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        if failed || !issues.isEmpty {
            Self.logger.error("questions: loadFailed=\(failed) issues=\(issues.count)")
            if assertOnFailure { assertionFailure("問題データに誤りがあります: \(issues)") }
        }
    }

    convenience init(bundle: Bundle = .main, resource: String = "questions") {
        let url = bundle.url(forResource: resource, withExtension: "json")
        self.init(data: url.flatMap { try? Data(contentsOf: $0) })
    }

    static func validate(_ questions: [Question]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        var seen = Set<String>()
        for q in questions {
            if !seen.insert(q.id).inserted {
                issues.append(ValidationIssue(kind: .duplicateId, id: q.id))
                continue
            }
            if !isValidId(q.id, domain: q.domain) {
                issues.append(ValidationIssue(kind: .invalidIdFormat, id: q.id))
            } else if !isValidAnswer(q.answer) {
                issues.append(ValidationIssue(kind: .invalidAnswer, id: q.id))
            }
        }
        return issues
    }

    /// `<分野の略称>-<4桁>`
    private static func isValidId(_ id: String, domain: Domain) -> Bool {
        let head = domain.idPrefix + "-"
        guard id.hasPrefix(head) else { return false }
        let number = id.dropFirst(head.count)
        return number.count == 4 && number.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// 数字と「.」だけで、数字を 1 つ以上含む
    private static func isValidAnswer(_ answer: String) -> Bool {
        !answer.isEmpty
            && answer.allSatisfy { $0 == "." || ($0.isASCII && $0.isNumber) }
            && answer.contains { $0.isNumber }
    }

    func question(id: String) -> Question? {
        byId[id] ?? SubnetQuestionGenerator.question(fromId: id)
    }

    func handwrittenCount(in domain: Domain) -> Int {
        handwritten.filter { $0.domain == domain }.count
    }
}
