import Foundation
import Testing
@testable import NetTre

/// 06 基本設計テスト（結合）のうち、Swift Testing で自動化するもの
@MainActor
struct LearningFlowIntegrationTests {
    let builder = SessionBuilder()
    let cal = TestSupport.calendar

    func session(_ scope: SessionScope, day: Int, db: InMemoryStore,
                 repo: QuestionRepository = TestSupport.repository(),
                 store: (any ReviewRecording)? = nil) throws -> QuizSessionViewModel {
        let now = TestSupport.day(day)
        var rng = SeededRNG(seed: 42 &+ UInt64(day))
        let recorder = store ?? db.store
        let s = try builder.buildSession(scope: scope, now: now, calendar: cal, store: db.store,
                                         repository: repo, rng: &rng)
        return QuizSessionViewModel(questions: s.questions, reviewIds: s.reviewIds, scope: scope,
                                    store: recorder, now: { now })
    }

    func answer(_ vm: QuizSessionViewModel, correct: Bool) {
        guard let q = vm.current else { return }
        vm.input = correct ? q.answer : "0"
        vm.submit()
        vm.next()
    }

    /// 06 §1.1 の標準の回答パターン P1
    func runP1(_ db: InMemoryStore) throws -> QuizSessionViewModel {
        let vm = try session(.mixed, day: 1, db: db)
        let pattern = [true, false, true, false, true, false, false, true, true, true]
        for correct in pattern { answer(vm, correct: correct) }
        return vm
    }

    @Test("IT-LF-01")
    func fullSession() throws {
        let db = InMemoryStore()
        let vm = try runP1(db)
        #expect(vm.phase == .finished)
        #expect(vm.questions.prefix(5).map(\.id) == ids("net-fund", 1...5))
        #expect(db.logs().count == 10)
        #expect(db.logs().filter(\.isCorrect).count == 6)
        #expect(db.records().count == 7)
        #expect(check(db.records().allSatisfy { $0.dueDate == TestSupport.date(2026, 10, 19) }))
    }

    @Test("IT-LF-02")
    func wrongComesFirstNextDay() throws {
        let db = InMemoryStore()
        let vm = try session(.domain(.networkAccess), day: 1, db: db)
        for _ in 0..<3 { answer(vm, correct: false) }
        vm.quit()
        let next = try session(.mixed, day: 2, db: db)
        #expect(next.questions.prefix(3).map(\.id) == ["net-access-0001", "net-access-0002", "net-access-0003"])
        #expect(next.reviewIds.count == 3)
    }

    @Test("IT-LF-03")
    func intervalGrows() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.repository().question(id: "net-fund-0001")!,
                                  correct: true, now: TestSupport.day(1))
        func dueIds(_ day: Int) throws -> [String] {
            try db.store.dueRecords(in: .mixed, now: TestSupport.day(day)).map(\.questionId)
        }
        #expect(try dueIds(2) == ["net-fund-0001"])
        let day2 = try session(.mixed, day: 2, db: db)
        #expect(day2.current?.id == "net-fund-0001")
        answer(day2, correct: true)
        #expect(try dueIds(3).isEmpty)
        #expect(try dueIds(4).isEmpty)
        #expect(try dueIds(5) == ["net-fund-0001"])
    }

    @Test("IT-LF-04")
    func generatedReplayAndGraduation() throws {
        let db = InMemoryStore()
        let day1 = try session(.subnetDrill(.standard), day: 1, db: db)
        let x = try #require(day1.current)
        answer(day1, correct: false)
        day1.quit()

        let day2 = try session(.subnetDrill(.standard), day: 2, db: db)
        #expect(day2.current == x)
        answer(day2, correct: true)
        day2.quit()

        // 2 日目の正解で interval 1 → 3 日目に出る
        let day3 = try session(.subnetDrill(.standard), day: 3, db: db)
        #expect(day3.current == x)
        answer(day3, correct: true)
        day3.quit()
        #expect(db.records().isEmpty)
        for day in 4...10 {
            #expect(try db.store.dueRecords(in: .mixed, now: TestSupport.day(day)).isEmpty)
        }
    }

    @Test("IT-LF-05")
    func quitKeepsAnswers() throws {
        let db = InMemoryStore()
        let vm = try session(.mixed, day: 1, db: db)
        for _ in 0..<3 { answer(vm, correct: true) }
        vm.quit()
        #expect(vm.phase == .finished)
        #expect(vm.outcomes.count == 3)
        #expect(db.logs().count == 3)
        #expect(try db.store.summary(now: TestSupport.day(1)).total.answered == 3)
    }

    @Test("IT-LF-06")
    func versionChangeKeepsHistory() throws {
        let db = InMemoryStore()
        let v1 = TestSupport.repository()
        try db.store.recordAnswer(question: v1.question(id: "net-fund-0001")!, correct: true, now: TestSupport.day(1))
        let v2Questions = TestSupport.testQuestions().map { q in
            q.id == "net-fund-0001"
                ? Question(id: q.id, domain: q.domain, tags: q.tags, difficulty: q.difficulty, stem: q.stem + "（改）",
                           answer: q.answer, explanation: q.explanation, version: 2)
                : q
        }
        let v2 = TestSupport.repository(v2Questions)
        let day2 = try session(.mixed, day: 2, db: db, repo: v2)
        #expect(day2.current?.version == 2)
        answer(day2, correct: true)
        let record = try #require(db.records().first { $0.questionId == "net-fund-0001" })
        #expect(record.streak == 2)
        #expect(record.interval == 3)
        #expect(record.questionVersion == 2)
        #expect(record.dueDate == TestSupport.date(2026, 10, 22))
    }

    @Test("IT-LF-07")
    func deletedQuestionSkipped() throws {
        let db = InMemoryStore()
        let vm = try session(.domain(.networkAccess), day: 1, db: db)
        for _ in 0..<3 { answer(vm, correct: false) }
        let repo = TestSupport.repository(TestSupport.testQuestions().filter { $0.id != "net-access-0002" })
        let next = try session(.mixed, day: 2, db: db, repo: repo)
        #expect(next.questions.prefix(2).map(\.id) == ["net-access-0001", "net-access-0003"])
        #expect(next.questions.count == 10)
    }

    @Test("IT-LF-08")
    func domainScope() throws {
        let db = InMemoryStore()
        #expect(try session(.domain(.networkAccess), day: 1, db: db).questions.map(\.id)
            == ids("net-access", 1...4))
        #expect(try session(.domain(.ipServices), day: 1, db: db).questions.isEmpty)
    }

    @Test("IT-LF-09")
    func subnetDrillAdvanced() throws {
        let db = InMemoryStore()
        let vm = try session(.subnetDrill(.advanced), day: 1, db: db)
        #expect(vm.questions.count == 10)
        for q in vm.questions {
            #expect(q.isGenerated && q.difficulty == .advanced)
            let s = try #require(SubnetQuestionGenerator.subnet(fromId: q.id))
            #expect(check((17...30).contains(s.prefix)))
            #expect(q.answer == SubnetQuestionGeneratorTests.expectedAnswer(SubnetQuestionGenerator.parse(q.id)!.type, s))
        }
        for _ in 0..<10 { answer(vm, correct: true) }
        #expect(vm.phase == .finished)
        #expect(vm.correctCount == 10)
    }

    @Test("IT-LF-10")
    func statsAfterP1() throws {
        let db = InMemoryStore()
        _ = try runP1(db)
        let vm = StatsViewModel(store: db.store, now: { TestSupport.day(1) })
        vm.refresh()
        #expect(vm.summary.total.answered == 10)
        #expect(StatsViewModel.percentText(vm.summary.total) == "60%")
        #expect(vm.percentText(for: "サブネット計算") == "60%")
        #expect(vm.summary.subnet.answered == 5)
        #expect(vm.percentText(for: "ネットワークの基礎") == "60%")
        #expect(vm.summary.byDomain[.networkFundamentals]?.answered == 5)
        #expect(vm.percentText(for: "ネットワークアクセス") == "まだ回答していません")
        #expect(vm.summary.answeredToday == 10)
        #expect(vm.summary.dueToday == 0)
    }

    @Test("IT-LF-11")
    func homeNextDay() throws {
        let db = InMemoryStore()
        _ = try runP1(db)
        let vm = HomeViewModel(store: db.store, now: { TestSupport.day(2) })
        vm.refresh()
        #expect(vm.dueToday == 7)
        #expect(vm.answeredToday == 0)
    }

    @Test("IT-LF-12")
    func reset() throws {
        let db = InMemoryStore()
        _ = try runP1(db)
        try db.store.deleteAll()
        let home = HomeViewModel(store: db.store, now: { TestSupport.day(1) })
        home.refresh()
        #expect(home.dueToday == 0)
        #expect(home.dueMessage == "まずは1回、解いてみましょう")
        let stats = StatsViewModel(store: db.store, now: { TestSupport.day(1) })
        stats.refresh()
        #expect(!stats.hasHistory)
        #expect(try session(.mixed, day: 2, db: db).reviewIds.isEmpty)
    }

    @Test("IT-LF-13")
    func domainList() throws {
        let db = InMemoryStore()
        let vm = try session(.domain(.networkAccess), day: 1, db: db)
        for _ in 0..<3 { answer(vm, correct: false) }
        let list = DomainListViewModel(store: db.store, repository: TestSupport.repository(), now: { TestSupport.day(2) })
        list.refresh()
        let access = try #require(list.row(.networkAccess))
        #expect(access.questionCount == 4 && access.dueCount == 3 && access.rateText == "0%")
        let fund = try #require(list.row(.networkFundamentals))
        #expect(fund.questionCount == 12 && fund.dueCount == 0 && fund.rateText == "―")
        #expect(list.row(.ipServices)?.isAvailable == false)
    }

    @Test("IT-ER-01")
    func brokenQuestionData() throws {
        let db = InMemoryStore()
        let repo = QuestionRepository(data: Data("{ broken".utf8), assertOnFailure: false)
        let vm = try session(.mixed, day: 1, db: db, repo: repo)
        #expect(vm.questions.count == 10)
        #expect(check(vm.questions.allSatisfy(\.isGenerated)))
        for _ in 0..<10 { answer(vm, correct: true) }
        #expect(db.logs().count == 10)
        #expect(try db.store.summary(now: TestSupport.day(1)).total.answered == 10)
    }

    @Test("IT-ER-02")
    func saveFailureContinues() throws {
        let db = InMemoryStore()
        let failing = FailingRecorder(base: db.store)
        let vm = try session(.mixed, day: 1, db: db, store: failing)
        for _ in 0..<3 {
            vm.input = "1"
            vm.submit()
            #expect(vm.saveFailed)
            vm.next()
        }
        #expect(vm.index == 3)
        #expect(try db.store.summary(now: TestSupport.day(1)).total.answered == 0)
    }

    @Test("IT-NF-04 問題を 1 問足すだけで出題される")
    func addQuestionWithoutCode() throws {
        let extra = Question(id: "ip-svc-0001", domain: .ipServices, tags: [], difficulty: .basic,
                             stem: "NTP のポート番号を答えよ。", answer: "123", explanation: "UDP 123", version: 1)
        let repo = TestSupport.repository(TestSupport.testQuestions() + [extra])
        let vm = try session(.domain(.ipServices), day: 1, db: InMemoryStore(), repo: repo)
        #expect(vm.questions.map(\.id) == ["ip-svc-0001"])
    }
}

/// 06 §3 計算機（自動）
@MainActor
struct CalculatorIntegrationTests {
    func expectStandard(_ vm: CIDRCalculatorViewModel) throws {
        let r = try #require(try? vm.result?.get())
        #expect(r.subnet.cidrString == "192.168.10.64/26")
        #expect(r.subnet.broadcast.description == "192.168.10.127")
        #expect(r.subnet.usableHosts == 62)
        #expect(r.kind == .private)
        #expect(r.steps.count == 2)
    }

    @Test("IT-CA-01・02")
    func cidrInputs() throws {
        let a = CIDRCalculatorViewModel()
        a.addressText = "１９２．１６８．１０．７７"
        a.prefixText = "26"
        try expectStandard(a)
        let b = CIDRCalculatorViewModel()
        b.addressText = "192,168,10,77"
        b.prefixText = "26"
        try expectStandard(b)
        let c = CIDRCalculatorViewModel()
        c.paste("192.168.10.77 255.255.255.192")
        try expectStandard(c)
    }

    @Test("IT-CA-03")
    func cidrError() {
        let vm = CIDRCalculatorViewModel(address: "192.168.256.1", prefix: "26")
        guard case let .failure(e) = vm.result else {
            Issue.record("誤りになっていない")
            return
        }
        #expect(e.message == "第3オクテットが 256 です（0〜255）")
        #expect(vm.network.addressError?.message == "第3オクテットが 256 です（0〜255）")
    }

    @Test("IT-CA-04")
    func splitLimit() throws {
        let vm = SubnetSplitViewModel()
        vm.network = NetworkInput(addressText: "10.0.0.0", prefixText: "8")
        vm.kind = .hosts
        vm.numberText = "2"
        let r = try #require(try? vm.result?.get())
        #expect(r.subnets.count == 256)
        #expect(vm.truncationNote == "全 4,194,304 件のうち先頭 256 件")
    }

    @Test("IT-CA-05")
    func vlsmShortage() {
        let vm = VLSMViewModel()
        vm.network = NetworkInput(addressText: "192.168.10.0", prefixText: "26")
        vm.rows = [VLSMViewModel.Row(name: "A", hostsText: "50"), VLSMViewModel.Row(name: "B", hostsText: "25")]
        #expect(vm.result == .failure(CalcFailure(message: "✗ 親ネットワークに 32 アドレス足りません")))
    }

    @Test("IT-CA-06")
    func summaryHostBits() throws {
        let vm = RouteSummaryViewModel()
        vm.rows[0].network = NetworkInput(addressText: "192.168.0.0", prefixText: "24")
        vm.rows[1].network = NetworkInput(addressText: "192.168.1.77", prefixText: "24")
        let r = try #require(try? vm.result?.get())
        #expect(r.route.cidrString == "192.168.0.0/23")
        #expect(vm.hostBitsNote == "ホスト部を 0 にして扱いました")
        #expect(vm.extraText == "ありません（ちょうど集約できます）")
    }

    @Test("IT-CA-07")
    func radixDetection() throws {
        let expected = ("255.255.255.192", "11111111.11111111.11111111.11000000", "FF.FF.FF.C0")
        for (input, label) in [("0xFFFFFFC0", "16 進"), ("11111111.11111111.11111111.11000000", "2 進"),
                               ("255.255.255.192", "10 進")] {
            let vm = RadixViewModel()
            vm.input = input
            #expect(vm.detectedText == "\(label)として読みました")
            let v = try #require(try? vm.result?.get()).value
            #expect((v.description, v.binaryString, v.hexString) == expected)
        }
    }

    @Test("IT-CA-08 問題から計算機へ")
    func questionToCalculator() throws {
        for type in SubnetQuestionType.allCases {
            for seed in UInt64(1)...20 {
                let q = SubnetQuestionGenerator.make(type: type, seed: seed, difficulty: .standard)
                let s = try #require(SubnetQuestionGenerator.subnet(fromId: q.id))
                let vm = CIDRCalculatorViewModel(address: s.address.description, prefix: String(s.prefix))
                let r = try #require(try? vm.result?.get())
                let value: String = switch type {
                case .networkAddress: r.subnet.network.description
                case .broadcastAddress: r.subnet.broadcast.description
                case .hostCount: String(r.subnet.usableHosts)
                case .maskFromPrefix: r.subnet.mask.description
                case .lastHost: r.subnet.lastHost.description
                }
                #expect(value == q.answer)
            }
        }
    }

    @Test("IT-CA-09 文字の入力から照合用データまで")
    func fixturesThroughViewModel() throws {
        let cases = try TestSupport.fixture("cidr_fixtures", as: [SubnetTests.CIDRFixture].self)
        var rng = SeededRNG(seed: 42)
        for _ in 0..<200 {
            let c = cases[Int.random(in: 0..<cases.count, using: &rng)]
            let vm = CIDRCalculatorViewModel(address: c.address, prefix: String(c.prefix))
            let s = try #require(try? vm.result?.get()).subnet
            #expect(s.network.description == c.network)
            #expect(s.broadcast.description == c.broadcast)
            #expect(s.mask.description == c.mask)
            #expect(s.wildcard.description == c.wildcard)
            #expect(s.usableHosts == c.usable && s.totalAddresses == c.total)
            #expect(s.firstHost.description == c.first && s.lastHost.description == c.last)
        }
    }
}
