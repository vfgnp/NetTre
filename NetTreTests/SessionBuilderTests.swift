import Foundation
import Testing
@testable import NetTre

// 05 §6 学習の組み立て
@MainActor
struct SessionBuilderTests {
    let now = TestSupport.day1
    let past = TestSupport.date(2026, 10, 17)
    let builder = SessionBuilder()

    func build(_ scope: SessionScope, db: InMemoryStore, repo: QuestionRepository = TestSupport.repository(),
               seed: UInt64 = 42) throws -> [Question] {
        var rng = SeededRNG(seed: seed)
        return try builder.build(scope: scope, now: now, calendar: TestSupport.calendar, store: db.store,
                                 repository: repo, rng: &rng)
    }

    @Test("UT-SB-01")
    func mixedWithoutHistory() throws {
        let qs = try build(.mixed, db: InMemoryStore())
        #expect(qs.count == 10)
        #expect(qs.prefix(5).map(\.id) == ids("net-fund", 1...5))
        #expect(check(qs.suffix(5).allSatisfy(\.isGenerated)))
    }

    @Test("UT-SB-02")
    func mixedWithReviews() throws {
        let db = InMemoryStore()
        db.insertRecord("net-access-0002", due: TestSupport.date(2026, 10, 16), domain: .networkAccess)
        db.insertRecord("net-access-0001", due: past, domain: .networkAccess)
        db.insertRecord("ip-conn-0001", due: TestSupport.date(2026, 10, 15), domain: .ipConnectivity)
        let qs = try build(.mixed, db: db)
        #expect(qs.count == 10)
        #expect(qs.prefix(3).map(\.id) == ["ip-conn-0001", "net-access-0002", "net-access-0001"])
        #expect(qs[3..<7].map(\.id) == ids("net-fund", 1...4))
        #expect(check(qs.suffix(3).allSatisfy(\.isGenerated)))
    }

    @Test("UT-SB-03")
    func allReviews() throws {
        let db = InMemoryStore()
        for i in 1...12 { db.insertRecord(String(format: "net-fund-%04d", i), due: past) }
        let qs = try build(.mixed, db: db)
        #expect(qs.count == 10)
        #expect(qs.map(\.id) == ids("net-fund", 1...10))
    }

    @Test("UT-SB-04・05")
    func domainScope() throws {
        let access = try build(.domain(.networkAccess), db: InMemoryStore())
        #expect(access.map(\.id) == ids("net-access", 1...4))
        #expect(try build(.domain(.ipServices), db: InMemoryStore()).isEmpty)
    }

    @Test("UT-SB-06")
    func subnetDrillBasic() throws {
        let qs = try build(.subnetDrill(.basic), db: InMemoryStore())
        #expect(qs.count == 10)
        #expect(check(qs.allSatisfy { $0.isGenerated && $0.difficulty == .basic }))
    }

    @Test("UT-SB-07")
    func subnetDrillWithReviews() throws {
        let db = InMemoryStore()
        db.insertRecord("gen-subnet-hostCount-3-11", due: past)
        db.insertRecord("gen-subnet-lastHost-3-12", due: past)
        db.insertRecord("gen-subnet-hostCount-1-13", due: past)
        let qs = try build(.subnetDrill(.advanced), db: db)
        #expect(qs.count == 10)
        #expect(qs.prefix(2).map(\.id) == ["gen-subnet-hostCount-3-11", "gen-subnet-lastHost-3-12"])
        #expect(check(qs.allSatisfy { $0.difficulty == .advanced }))
        #expect(Set(qs.map(\.id)).count == 10)
    }

    @Test("UT-SB-08")
    func mixedGeneratedIsStandard() throws {
        let qs = try build(.mixed, db: InMemoryStore())
        #expect(check(qs.filter(\.isGenerated).allSatisfy { $0.difficulty == .standard }))
    }

    @Test("UT-SB-09")
    func skipDeletedQuestion() throws {
        let db = InMemoryStore()
        db.insertRecord("net-access-0001", due: past, domain: .networkAccess)
        db.insertRecord("net-fund-0999", due: past)
        db.insertRecord("net-access-0002", due: past, domain: .networkAccess)
        let qs = try build(.mixed, db: db)
        #expect(qs.count == 10)
        #expect(qs.prefix(2).map(\.id) == ["net-access-0001", "net-access-0002"])
        #expect(qs[2..<6].map(\.id) == ids("net-fund", 1...4))
        #expect(check(qs.suffix(4).allSatisfy(\.isGenerated)))
    }

    @Test("UT-SB-10")
    func deterministic() throws {
        let a = try build(.mixed, db: InMemoryStore(), seed: 99).map(\.id)
        let b = try build(.mixed, db: InMemoryStore(), seed: 99).map(\.id)
        #expect(a == b)
    }

    @Test("UT-SB-11 ID が重なったら引き直す")
    func retryOnDuplicate() throws {
        let db = InMemoryStore()
        var rng = RepeatingStubRNG(k: 2)
        let qs = try builder.build(scope: .subnetDrill(.standard), now: now, calendar: TestSupport.calendar,
                                   store: db.store, repository: TestSupport.repository(), rng: &rng)
        #expect(qs.count == 10)
        #expect(Set(qs.map(\.id)).count == 10)
        #expect(rng.calls > 20)
    }

    @Test("UT-SB-11 引き直しても重なるときは入れずに進む")
    func giveUpAfterRetries() throws {
        let db = InMemoryStore()
        var rng = CyclingStubRNG(k: 2)
        let qs = try builder.build(scope: .subnetDrill(.standard), now: now, calendar: TestSupport.calendar,
                                   store: db.store, repository: TestSupport.repository(), rng: &rng)
        #expect(qs.count == 1)
    }

    @Test("UT-SB-12")
    func allHandwrittenAnswered() throws {
        let db = InMemoryStore()
        for q in TestSupport.testQuestions() { db.insertLog(q.id, correct: true, at: past, domain: q.domain) }
        let qs = try build(.mixed, db: db)
        #expect(qs.count == 10)
        #expect(check(qs.allSatisfy { $0.isGenerated && $0.difficulty == .standard }))
    }
}
