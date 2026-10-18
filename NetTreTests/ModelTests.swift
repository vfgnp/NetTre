import Foundation
import Testing
@testable import NetTre

// 05 §2 入力の整形と回答の判定
struct AnswerNormalizerTests {
    @Test("UT-AN-01〜07", arguments: [
        ("１１０", "110"),
        ("192,168,10,64", "192.168.10.64"),
        (" 62 ", "62"), ("6 2", "62"), ("６２　", "62"),
        ("１９２．１６８．１．１", "192.168.1.1"),
        ("１９２，１６８，１，１", "192.168.1.1"),
        ("0XFF", "0xff"),
        ("", ""), ("   ", ""),
    ])
    func normalize(input: String, expected: String) {
        #expect(AnswerNormalizer.normalize(input) == expected)
    }

    @Test("UT-AK-01・02")
    func keyboard() {
        #expect(AnswerKeyboard(for: "62") == .number)
        #expect(AnswerKeyboard(for: "192.168.10.64") == .decimal)
    }
}

struct QuestionModelTests {
    @Test("UT-QM-01〜03")
    func isCorrect() {
        #expect(TestSupport.handwritten("net-fund-0001", answer: "192.168.10.64").isCorrect("192,168,10,64"))
        #expect(TestSupport.handwritten("net-fund-0001", answer: "110").isCorrect("１１０ "))
        let q = TestSupport.handwritten("net-fund-0001", answer: "62")
        #expect(!q.isCorrect("64"))
        #expect(!q.isCorrect(""))
    }

    @Test("UT-QM-04")
    func isGenerated() {
        #expect(TestSupport.handwritten("gen-subnet-hostCount-2-1").isGenerated)
        #expect(!TestSupport.handwritten("net-fund-0001").isGenerated)
    }

    @Test("UT-QM-05")
    func codableRoundTrip() throws {
        let json = """
        [{"id":"net-fund-0001","domain":"network-fundamentals","tags":["osi"],"difficulty":1,
          "stem":"問題","answer":"2","explanation":"**解説**","version":3}]
        """
        let decoded = try JSONDecoder().decode([Question].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded[0].domain == .networkFundamentals)
        #expect(decoded[0].difficulty == .basic)
        #expect(decoded[0].version == 3)
        let again = try JSONDecoder().decode([Question].self, from: JSONEncoder().encode(decoded))
        #expect(again == decoded)
    }

    @Test("UT-QM-06")
    func domains() {
        let expected: [(Domain, String, String, String)] = [
            (.networkFundamentals, "network-fundamentals", "ネットワークの基礎", "net-fund"),
            (.networkAccess, "network-access", "ネットワークアクセス", "net-access"),
            (.ipConnectivity, "ip-connectivity", "IP 接続", "ip-conn"),
            (.ipServices, "ip-services", "IP サービス", "ip-svc"),
            (.securityFundamentals, "security-fundamentals", "セキュリティの基礎", "sec-fund"),
            (.automationProgrammability, "automation-programmability", "自動化とプログラマビリティ", "auto-prog"),
        ]
        #expect(Domain.allCases.count == 6)
        for (domain, raw, name, prefix) in expected {
            #expect(domain.rawValue == raw)
            #expect(domain.displayName == name)
            #expect(domain.idPrefix == prefix)
        }
    }
}

// 05 §3 間隔反復
struct ReviewStateTests {
    let cal = TestSupport.calendar
    let now = TestSupport.day1

    @Test("UT-RS-01")
    func firstCorrect() {
        var s = ReviewState(dueDate: now)
        s.record(correct: true, now: now, calendar: cal)
        #expect(s.streak == 1)
        #expect(s.interval == 1)
        #expect(abs(s.ease - 2.6) < 1e-9)
        #expect(s.dueDate == TestSupport.date(2026, 10, 19))
    }

    @Test("UT-RS-02")
    func secondCorrect() {
        var s = ReviewState(dueDate: now)
        s.record(correct: true, now: now, calendar: cal)
        s.record(correct: true, now: now, calendar: cal)
        #expect(s.streak == 2)
        #expect(s.interval == 3)
        #expect(s.dueDate == TestSupport.date(2026, 10, 21))
    }

    @Test("UT-RS-03")
    func thirdCorrect() {
        var s = ReviewState(interval: 3, ease: 2.7, streak: 2, dueDate: now)
        s.record(correct: true, now: now, calendar: cal)
        #expect(s.interval == 8)
        #expect(abs(s.ease - 2.8) < 1e-9)
    }

    @Test("UT-RS-04 今の ease で計算してから上げる")
    func orderOfEase() {
        var s = ReviewState(interval: 8, ease: 2.8, streak: 3, dueDate: now)
        s.record(correct: true, now: now, calendar: cal)
        #expect(s.interval == 22)
        #expect(abs(s.ease - 2.9) < 1e-9)
    }

    @Test("UT-RS-05")
    func easeMax() {
        var s = ReviewState(dueDate: now)
        for _ in 0..<10 { s.record(correct: true, now: now, calendar: cal) }
        #expect(s.ease == 3.0)
    }

    @Test("UT-RS-06")
    func wrong() {
        var s = ReviewState(interval: 3, ease: 2.7, streak: 2, dueDate: now)
        s.record(correct: false, now: now, calendar: cal)
        #expect(s.streak == 0)
        #expect(s.interval == 1)
        #expect(abs(s.ease - 2.5) < 1e-9)
        #expect(s.dueDate == TestSupport.date(2026, 10, 19))
    }

    @Test("UT-RS-07")
    func easeMin() {
        var s = ReviewState(dueDate: now)
        for _ in 0..<10 { s.record(correct: false, now: now, calendar: cal) }
        #expect(s.ease == 1.3)
    }

    @Test("UT-RS-08 日付単位")
    func lateNight() {
        let late = TestSupport.date(2026, 10, 18, 23, 59)
        var s = ReviewState(dueDate: late)
        s.record(correct: true, now: late, calendar: cal)
        #expect(s.dueDate == TestSupport.date(2026, 10, 19))
    }
}
