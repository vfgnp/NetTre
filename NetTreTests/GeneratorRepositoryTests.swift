import Foundation
import Testing
@testable import NetTre

// 05 §5 問題の生成と取得
struct SubnetQuestionGeneratorTests {
    static let allCombinations: [(SubnetQuestionType, Difficulty)] =
        SubnetQuestionType.allCases.flatMap { t in Difficulty.allCases.map { (t, $0) } }

    @Test("UT-GN-01")
    func idFormat() {
        let q = SubnetQuestionGenerator.make(type: .hostCount, seed: 918273, difficulty: .standard)
        #expect(q.id == "gen-subnet-hostCount-2-918273")
    }

    @Test("UT-GN-02")
    func reproducible() {
        #expect(SubnetQuestionGenerator.make(type: .lastHost, seed: 42, difficulty: .advanced)
            == SubnetQuestionGenerator.make(type: .lastHost, seed: 42, difficulty: .advanced))
    }

    @Test("UT-GN-03〜07", arguments: allCombinations)
    func generatedQuestions(type: SubnetQuestionType, difficulty: Difficulty) throws {
        for seed in UInt64(1)...500 {
            let q = SubnetQuestionGenerator.make(type: type, seed: seed, difficulty: difficulty)
            let s = try #require(SubnetQuestionGenerator.subnet(fromId: q.id))

            // UT-GN-03 正解の正しさ
            #expect(q.answer == Self.expectedAnswer(type, s))

            // UT-GN-04 難易度の範囲
            switch difficulty {
            case .basic: #expect([8, 16, 24].contains(s.prefix))
            case .standard: #expect((24...30).contains(s.prefix))
            case .advanced: #expect((17...30).contains(s.prefix))
            }

            // UT-GN-05 アドレスの範囲
            let o = s.address.octets
            switch o[0] {
            case 10: #expect((1...254).contains(o[1]))
            case 172: #expect((16...31).contains(o[1]))
            case 192: #expect(o[1] == 168)
            default: Issue.record("第1オクテットが範囲外: \(s.address)")
            }
            #expect(check((1...254).contains(o[2]) && (1...254).contains(o[3])))

            // UT-GN-06 正解の形
            if type == .hostCount {
                #expect(check(q.answer.allSatisfy(\.isNumber)))
                #expect(q.keyboard == .number)
            } else {
                let parsed = (try? IPv4InputParser.address(q.answer).get()) != nil
                #expect(parsed)
                #expect(q.keyboard == .decimal)
            }

            // UT-GN-07 ID から戻せる
            #expect(SubnetQuestionGenerator.question(fromId: q.id) == q)
        }
    }

    static func expectedAnswer(_ type: SubnetQuestionType, _ s: Subnet) -> String {
        switch type {
        case .networkAddress: s.network.description
        case .broadcastAddress: s.broadcast.description
        case .hostCount: String(s.usableHosts)
        case .maskFromPrefix: s.mask.description
        case .lastHost: s.lastHost.description
        }
    }

    @Test("UT-GN-08", arguments: [
        "gen-subnet-unknown-2-1", "gen-subnet-hostCount-9-1", "gen-subnet-hostCount-0-1",
        "gen-subnet-hostCount-2-x", "gen-subnet-hostCount-2-1-9",
        "gen-subnet-hostCount-2-18446744073709551616", "", "abc",
    ])
    func invalidIds(id: String) {
        #expect(SubnetQuestionGenerator.question(fromId: id) == nil)
        #expect(SubnetQuestionGenerator.subnet(fromId: id) == nil)
    }

    @Test("UT-GN-09", arguments: [UInt64(0), UInt64.max])
    func seedBounds(seed: UInt64) throws {
        for type in SubnetQuestionType.allCases {
            let id = "gen-subnet-\(type.rawValue)-2-\(seed)"
            let q = try #require(SubnetQuestionGenerator.question(fromId: id))
            let s = try #require(SubnetQuestionGenerator.subnet(fromId: id))
            #expect(q.answer == Self.expectedAnswer(type, s))
        }
    }

    @Test("UT-GN-10")
    func fields() {
        for (type, difficulty) in Self.allCombinations {
            let q = SubnetQuestionGenerator.make(type: type, seed: 3, difficulty: difficulty)
            #expect(q.stem.hasSuffix("を答えよ。"))
            #expect(q.domain == .networkFundamentals)
            #expect(q.version == 1)
        }
    }

    @Test("UT-CS-06 解説に解き方の文がそのまま入る")
    func explanationContainsSteps() throws {
        for seed in UInt64(1)...50 {
            let q = SubnetQuestionGenerator.make(type: .networkAddress, seed: seed, difficulty: .standard)
            let s = try #require(SubnetQuestionGenerator.subnet(fromId: q.id))
            for step in CalculationSteps.cidr(s) {
                #expect(check(q.explanation.contains(step)))
            }
        }
    }
}

struct QuestionRepositoryTests {
    @Test("UT-RP-01")
    func loadsTestData() {
        let repo = TestSupport.repository()
        #expect(repo.handwritten.count == 20)
        #expect(repo.handwritten.first?.id == "net-fund-0001")
        #expect(repo.handwritten.last?.id == "ip-conn-0004")
        #expect(!repo.loadFailed)
        #expect(repo.issues.isEmpty)
        #expect(repo.handwrittenCount(in: .networkFundamentals) == 12)
        #expect(repo.handwrittenCount(in: .networkAccess) == 4)
        #expect(repo.handwrittenCount(in: .ipServices) == 0)
    }

    @Test("UT-RP-02 壊れた JSON・nil")
    func brokenData() {
        for data in [Data("{ broken".utf8), nil] {
            let repo = QuestionRepository(data: data, assertOnFailure: false)
            #expect(repo.handwritten.isEmpty)
            #expect(repo.loadFailed)
        }
    }

    @Test("UT-RP-02 重なりと誤りを含む 5 問")
    func partlyInvalid() throws {
        let qs = [
            TestSupport.handwritten("net-fund-0001", answer: "1"),
            TestSupport.handwritten("net-fund-0002", answer: "2"),
            TestSupport.handwritten("net-fund-0001", answer: "3"),
            TestSupport.handwritten("net-fund-0003", answer: "a/b"),
            TestSupport.handwritten("net-fund-0004", answer: "4"),
        ]
        let repo = QuestionRepository(data: try JSONEncoder().encode(qs), assertOnFailure: false)
        #expect(repo.handwritten.map(\.id) == ["net-fund-0001", "net-fund-0002", "net-fund-0004"])
        #expect(repo.handwritten.first?.answer == "1")
        #expect(repo.issues.count == 2)
        #expect(!repo.loadFailed)
    }

    @Test("UT-RP-03")
    func validate() {
        func kinds(_ qs: [Question]) -> [ValidationIssue.Kind] { QuestionRepository.validate(qs).map(\.kind) }
        let ok = TestSupport.handwritten("net-fund-0001")
        #expect(kinds([ok, ok]) == [.duplicateId])
        #expect(kinds([TestSupport.handwritten("netfund-1")]) == [.invalidIdFormat])
        #expect(kinds([TestSupport.handwritten("net-fund-0002", answer: "10/24")]) == [.invalidAnswer])
        #expect(kinds([TestSupport.handwritten("net-fund-0002", answer: "")]) == [.invalidAnswer])
        #expect(kinds([TestSupport.handwritten("net-fund-0002", answer: ".")]) == [.invalidAnswer])
    }

    @Test("UT-RP-04")
    func lookup() {
        let repo = TestSupport.repository()
        #expect(repo.question(id: "net-access-0002")?.domain == .networkAccess)
        let generated = repo.question(id: "gen-subnet-hostCount-2-918273")
        #expect(generated == SubnetQuestionGenerator.make(type: .hostCount, seed: 918273, difficulty: .standard))
        #expect(repo.question(id: "net-fund-9999") == nil)
    }

    @Test("UT-RP-05 同梱の questions.json")
    func bundledData() throws {
        let url = try #require(Bundle.main.url(forResource: "questions", withExtension: "json"))
        let qs = try JSONDecoder().decode([Question].self, from: Data(contentsOf: url))
        #expect(!qs.isEmpty)
        #expect(QuestionRepository.validate(qs).isEmpty)
    }
}
