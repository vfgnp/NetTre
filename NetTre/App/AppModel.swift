import Foundation
import Observation
import SwiftData

/// UI テスト用の起動引数（詳細設計 §12.9。デバッグビルドだけ有効）
struct LaunchOptions {
    var uitest = false
    var persistentStore = false
    var resetStore = false
    var failModelContainer = false
    var brokenQuestions = false
    var keepDefaults = false
    var day = 1

    static let current: LaunchOptions = {
        #if DEBUG
        return LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        #else
        return LaunchOptions()
        #endif
    }()

    init() {}

    init(arguments args: [String]) {
        uitest = args.contains("-uitest")
        persistentStore = args.contains("-uitestPersistentStore")
        resetStore = args.contains("-uitestResetStore")
        failModelContainer = args.contains("-uitestFailModelContainer")
        brokenQuestions = args.contains("-uitestBrokenQuestions")
        keepDefaults = args.contains("-uitestKeepDefaults")
        if let i = args.firstIndex(of: "-uitestDay"), args.indices.contains(i + 1), let n = Int(args[i + 1]), n >= 1 {
            day = n
        }
    }
}

enum DefaultsKey {
    static let subnetDrillDifficulty = "subnetDrillDifficulty"
}

/// アプリ全体で共有するもの（問題・学習履歴・計算機の入力）
@Observable @MainActor
final class AppModel {
    let environment: AppEnvironment
    let repository: QuestionRepository
    let calculators = CalculatorStore()
    private(set) var store: ReviewStore
    /// 学習履歴のデータベースが開けず、メモリ上で動いている（S-06 ⑤ を出す）
    private(set) var databaseFailed: Bool
    /// 履歴が変わったら増やす。各画面はこれを見て数字を読み直す
    private(set) var dataVersion = 0
    /// 表示中の学習（S-03・S-04）
    var activeSession: QuizSessionViewModel?

    private var container: ModelContainer
    private let options: LaunchOptions
    private var sessionCount: UInt64 = 0

    init(options: LaunchOptions = .current) {
        self.options = options

        var environment = AppEnvironment()
        if options.uitest {
            // 2026-10-18 08:00 JST を 1 日目とする
            let calendar = AppEnvironment.tokyoCalendar
            let day1 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 8)) ?? Date()
            let fixed = calendar.date(byAdding: .day, value: options.day - 1, to: day1) ?? day1
            environment.now = { fixed }
            environment.calendar = calendar
            CopyToastModel.displayDuration = 5
            if !options.keepDefaults {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.subnetDrillDifficulty)
            }
        }
        self.environment = environment

        if options.brokenQuestions {
            repository = QuestionRepository(data: Data("{ broken".utf8), assertOnFailure: false)
        } else if options.uitest {
            repository = QuestionRepository(resource: "questions_uitest")
        } else {
            repository = QuestionRepository()
        }

        let inMemory = options.uitest && !options.persistentStore
        if options.resetStore { Self.removeStoreFiles() }
        var failed = false
        let container: ModelContainer
        do {
            if options.failModelContainer { throw CocoaError(.fileReadCorruptFile) }
            container = try Self.makeContainer(inMemory: inMemory)
        } catch {
            // 履歴なしで起動するため、メモリ上のコンテナで代わりに動かす（§8）
            failed = true
            container = (try? Self.makeContainer(inMemory: true)) ?? Self.lastResortContainer()
        }
        self.container = container
        databaseFailed = failed
        store = ReviewStore(context: container.mainContext, calendar: environment.calendar)
    }

    var now: Date { environment.now() }

    // MARK: 学習

    func startSession(_ scope: SessionScope) {
        activeSession = makeSession(scope)
    }

    func makeSession(_ scope: SessionScope) -> QuizSessionViewModel {
        sessionCount += 1
        var rng: any RandomNumberGenerator = options.uitest
            ? SeededRNG(seed: 42 &+ sessionCount)
            : environment.makeRNG()
        let session = (try? SessionBuilder().buildSession(
            scope: scope, now: now, calendar: environment.calendar, store: store,
            repository: repository, rng: &rng
        )) ?? SessionBuilder.Session(questions: [], reviewIds: [])
        return QuizSessionViewModel(questions: session.questions, reviewIds: session.reviewIds,
                                    scope: scope, store: store, now: environment.now)
    }

    func historyChanged() { dataVersion += 1 }

    // MARK: 設定

    func deleteAll() throws {
        try store.deleteAll()
        historyChanged()
    }

    /// 保存ファイルを消してデータベースを作り直す（S-06 ⑤）
    func rebuildDatabase() throws {
        Self.removeStoreFiles()
        let container = try Self.makeContainer(inMemory: options.uitest && !options.persistentStore)
        self.container = container
        store = ReviewStore(context: container.mainContext, calendar: environment.calendar)
        databaseFailed = false
        historyChanged()
    }

    // MARK: 保存先

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "NetTre.store")
    }

    private static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([ReviewRecord.self, AnswerLog.self])
        if inMemory {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        return try ModelContainer(for: schema, configurations: ModelConfiguration(url: storeURL))
    }

    private static func lastResortContainer() -> ModelContainer {
        // メモリ上のコンテナも作れないときは続けられない
        guard let container = try? ModelContainer(for: ReviewRecord.self, AnswerLog.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        else { fatalError("ModelContainer を作れません") }
        return container
    }

    private static func removeStoreFiles() {
        let path = storeURL.path(percentEncoded: false)
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: path + suffix)
        }
    }
}
