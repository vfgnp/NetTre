import Foundation
import Observation

/// ホーム（S-01）
@Observable @MainActor
final class HomeViewModel {
    private(set) var summary = StatsSummary.empty

    private let store: any ReviewRecording
    private let now: () -> Date

    init(store: any ReviewRecording, now: @escaping () -> Date) {
        self.store = store
        self.now = now
    }

    func refresh() {
        summary = (try? store.summary(now: now())) ?? .empty
    }

    var dueToday: Int { summary.dueToday }
    var answeredToday: Int { summary.answeredToday }
    var hasHistory: Bool { summary.total.answered > 0 }

    /// ①の見出しの代わりに出す文。nil なら「n 問」を出す
    var dueMessage: String? {
        if !hasHistory { return "まずは1回、解いてみましょう" }
        if dueToday == 0 { return "今日の復習は終わりました" }
        return nil
    }
}

/// 分野選択（S-02、詳細設計 §12.12）
@Observable @MainActor
final class DomainListViewModel {
    struct Row: Identifiable, Equatable {
        let domain: Domain
        let questionCount: Int
        let dueCount: Int
        /// 未回答は「―」
        let rateText: String
        var id: Domain { domain }
        var isAvailable: Bool { questionCount > 0 }
    }

    private(set) var rows: [Row] = []

    private let store: any ReviewRecording
    private let repository: QuestionRepository
    private let now: () -> Date

    init(store: any ReviewRecording, repository: QuestionRepository, now: @escaping () -> Date) {
        self.store = store
        self.repository = repository
        self.now = now
    }

    func refresh() {
        let date = now()
        let summary = (try? store.summary(now: date)) ?? .empty
        rows = Domain.allCases.map { domain in
            Row(domain: domain,
                questionCount: repository.handwrittenCount(in: domain),
                dueCount: (try? store.dueRecords(in: .domain(domain), now: date).count) ?? 0,
                rateText: summary.byDomain[domain]?.percentText ?? "―")
        }
    }

    func row(_ domain: Domain) -> Row? { rows.first { $0.domain == domain } }
}

/// 成績（S-05）
@Observable @MainActor
final class StatsViewModel {
    struct Category: Identifiable, Equatable {
        let title: String
        let stats: CategoryStats
        var id: String { title }
    }

    private(set) var summary = StatsSummary.empty

    private let store: any ReviewRecording
    private let now: () -> Date

    init(store: any ReviewRecording, now: @escaping () -> Date) {
        self.store = store
        self.now = now
    }

    func refresh() {
        summary = (try? store.summary(now: now())) ?? .empty
    }

    var hasHistory: Bool { summary.total.answered > 0 }

    /// サブネット計算 → 6 分野の順
    var categories: [Category] {
        [Category(title: "サブネット計算", stats: summary.subnet)]
            + Domain.allCases.map { Category(title: $0.displayName, stats: summary.byDomain[$0] ?? .zero) }
    }

    static func percentText(_ stats: CategoryStats) -> String {
        stats.percentText ?? "まだ回答していません"
    }

    func percentText(for title: String) -> String? {
        categories.first { $0.title == title }.map { Self.percentText($0.stats) }
    }
}
