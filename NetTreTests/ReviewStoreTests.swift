import Foundation
import Testing
@testable import NetTre

// 05 §4 学習履歴の保存
@MainActor
struct ReviewStoreTests {
    let now = TestSupport.day1
    let tomorrow = TestSupport.date(2026, 10, 19)

    @Test("UT-ST-01・03")
    func handwrittenCorrect() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001"), correct: true, now: now)
        #expect(db.logs().count == 1)
        #expect(db.records().count == 1)
        #expect(db.records().first?.streak == 1)
        let log = try #require(db.logs().first)
        #expect(log.questionId == "net-fund-0001")
        #expect(log.domainRaw == "network-fundamentals")
        #expect(log.isGenerated == false)
        #expect(log.isCorrect == true)
        #expect(log.answeredAt == now)
    }

    @Test("UT-ST-02")
    func handwrittenWrong() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001"), correct: false, now: now)
        let record = try #require(db.records().first)
        #expect(record.streak == 0)
        #expect(record.dueDate == tomorrow)
    }

    @Test("UT-ST-04")
    func generatedCorrect() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.generated(), correct: true, now: now)
        #expect(db.logs().count == 1)
        #expect(db.records().isEmpty)
    }

    @Test("UT-ST-05・06")
    func generatedGraduates() throws {
        let db = InMemoryStore()
        let q = TestSupport.generated()
        try db.store.recordAnswer(question: q, correct: false, now: now)
        #expect(db.records().count == 1)
        #expect(db.records().first?.isGenerated == true)
        try db.store.recordAnswer(question: q, correct: true, now: TestSupport.day(2))
        #expect(db.records().count == 1)
        try db.store.recordAnswer(question: q, correct: true, now: TestSupport.day(3))
        #expect(db.records().isEmpty)
        #expect(db.logs().count == 3)
    }

    @Test("UT-ST-07")
    func generatedNotConsecutive() throws {
        let db = InMemoryStore()
        let q = TestSupport.generated()
        try db.store.recordAnswer(question: q, correct: false, now: now)
        try db.store.recordAnswer(question: q, correct: true, now: now)
        try db.store.recordAnswer(question: q, correct: false, now: now)
        try db.store.recordAnswer(question: q, correct: true, now: now)
        #expect(db.records().count == 1)
    }

    @Test("UT-ST-08")
    func versionUpdate() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001", version: 1), correct: true, now: now)
        try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001", version: 2), correct: true, now: now)
        #expect(db.records().count == 1)
        #expect(db.records().first?.questionVersion == 2)
    }

    @Test("UT-ST-09")
    func dueOrder() throws {
        let db = InMemoryStore()
        db.insertRecord("net-fund-0003", due: TestSupport.date(2026, 10, 19))
        db.insertRecord("net-fund-0002", due: TestSupport.date(2026, 10, 18))
        db.insertRecord("net-fund-0001", due: TestSupport.date(2026, 10, 17))
        let ids = try db.store.dueRecords(in: .mixed, now: now).map(\.questionId)
        #expect(ids == ["net-fund-0001", "net-fund-0002"])
    }

    @Test("UT-ST-10")
    func dueExactlyNow() throws {
        let db = InMemoryStore()
        db.insertRecord("net-fund-0001", due: now)
        #expect(try db.store.dueRecords(in: .mixed, now: now).count == 1)
    }

    @Test("UT-ST-11")
    func sameDueSortedById() throws {
        let db = InMemoryStore()
        db.insertRecord("net-fund-0002", due: TestSupport.date(2026, 10, 18))
        db.insertRecord("net-fund-0001", due: TestSupport.date(2026, 10, 18))
        let ids = try db.store.dueRecords(in: .mixed, now: now).map(\.questionId)
        #expect(ids == ["net-fund-0001", "net-fund-0002"])
    }

    @Test("UT-ST-12")
    func dueByDomain() throws {
        let db = InMemoryStore()
        let due = TestSupport.date(2026, 10, 18)
        db.insertRecord("net-fund-0001", due: due)
        db.insertRecord("net-fund-0002", due: due)
        db.insertRecord("gen-subnet-hostCount-2-1", due: due, domain: .networkFundamentals)
        let ids = try db.store.dueRecords(in: .domain(.networkFundamentals), now: now).map(\.questionId)
        #expect(ids == ["net-fund-0001", "net-fund-0002"])
    }

    @Test("UT-ST-13")
    func dueBySubnetDrill() throws {
        let db = InMemoryStore()
        let due = TestSupport.date(2026, 10, 18)
        db.insertRecord("gen-subnet-hostCount-3-1", due: due)
        db.insertRecord("gen-subnet-hostCount-1-2", due: due)
        db.insertRecord("gen-subnet-lastHost-3-5", due: due)
        db.insertRecord("net-fund-0001", due: due)
        let ids = try db.store.dueRecords(in: .subnetDrill(.advanced), now: now).map(\.questionId)
        #expect(ids == ["gen-subnet-hostCount-3-1", "gen-subnet-lastHost-3-5"])
    }

    @Test("UT-ST-14")
    func summaryCounts() throws {
        let db = InMemoryStore()
        db.insertLog("net-fund-0001", correct: true, at: now)
        db.insertLog("net-fund-0002", correct: true, at: now)
        db.insertLog("net-fund-0003", correct: false, at: now)
        db.insertLog("gen-subnet-hostCount-2-1", correct: true, at: now)
        db.insertLog("gen-subnet-hostCount-2-2", correct: false, at: now)
        let s = try db.store.summary(now: now)
        #expect(s.total == CategoryStats(answered: 5, correct: 3))
        #expect(s.subnet == CategoryStats(answered: 2, correct: 1))
        let fund = try #require(s.byDomain[.networkFundamentals])
        #expect(fund == CategoryStats(answered: 3, correct: 2))
        #expect(abs((fund.rate ?? 0) - 2.0 / 3.0) < 1e-9)
        #expect(fund.percentText == "67%")
    }

    @Test("UT-ST-15")
    func summaryEmptyRate() throws {
        let db = InMemoryStore()
        let s = try db.store.summary(now: now)
        #expect(s.total.rate == nil)
        #expect(s.byDomain[.ipServices]?.rate == nil)
    }

    @Test("UT-ST-16")
    func answeredToday() throws {
        let db = InMemoryStore()
        db.insertLog("net-fund-0001", correct: true, at: TestSupport.date(2026, 10, 17, 23, 59))
        db.insertLog("net-fund-0002", correct: true, at: TestSupport.date(2026, 10, 18))
        db.insertLog("net-fund-0003", correct: true, at: now)
        #expect(try db.store.summary(now: now).answeredToday == 2)
    }

    @Test("UT-ST-17")
    func dueToday() throws {
        let db = InMemoryStore()
        db.insertRecord("net-fund-0001", due: TestSupport.date(2026, 10, 17))
        db.insertRecord("net-fund-0002", due: TestSupport.date(2026, 10, 18))
        db.insertRecord("net-fund-0003", due: TestSupport.date(2026, 10, 19))
        #expect(try db.store.summary(now: now).dueToday == 2)
    }

    @Test("UT-ST-18")
    func answeredIds() throws {
        let db = InMemoryStore()
        db.insertLog("net-fund-0001", correct: true, at: now)
        db.insertLog("net-fund-0001", correct: false, at: now)
        db.insertLog("net-fund-0002", correct: true, at: now)
        #expect(try db.store.answeredQuestionIds() == ["net-fund-0001", "net-fund-0002"])
    }

    @Test("UT-ST-19")
    func deleteAll() throws {
        let db = InMemoryStore()
        try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001"), correct: false, now: now)
        try db.store.deleteAll()
        #expect(db.records().isEmpty)
        #expect(db.logs().isEmpty)
    }

    @Test("UT-ST-20 保存の失敗でロールバック")
    func saveFailureRollsBack() {
        let db = InMemoryStore(save: { throw TestError() })
        #expect(throws: TestError.self) {
            try db.store.recordAnswer(question: TestSupport.handwritten("net-fund-0001"), correct: false, now: now)
        }
        #expect(db.logs().isEmpty)
        #expect(db.records().isEmpty)
    }
}
