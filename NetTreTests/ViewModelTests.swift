import Foundation
import Testing
@testable import NetTre

// 05 §8 ViewModel
@MainActor
struct QuizSessionViewModelTests {
    let questions = [
        TestSupport.handwritten("net-fund-0001", answer: "62"),
        TestSupport.handwritten("net-fund-0002", answer: "192.168.10.64"),
        TestSupport.handwritten("net-fund-0003", answer: "110"),
    ]

    func make(_ store: (any ReviewRecording)? = nil, questions: [Question]? = nil) -> QuizSessionViewModel {
        QuizSessionViewModel(questions: questions ?? self.questions, scope: .mixed, store: store ?? CountingRecorder(),
                             now: { TestSupport.day1 })
    }

    @Test("UT-VM-01")
    func canSubmit() {
        let vm = make()
        #expect(!vm.canSubmit)
        vm.input = "   "
        #expect(!vm.canSubmit)
        vm.input = "6"
        #expect(vm.canSubmit)
    }

    @Test("UT-VM-02")
    func submitCorrect() {
        let recorder = CountingRecorder()
        let vm = make(recorder)
        vm.input = "６２"
        vm.submit()
        #expect(vm.phase == .answered(correct: true))
        #expect(vm.outcomes.count == 1)
        #expect(recorder.recorded.count == 1)
    }

    @Test("UT-VM-03・04")
    func nextAndFinish() {
        let vm = make()
        vm.input = "1"
        vm.submit()
        vm.next()
        #expect(vm.index == 1)
        #expect(vm.input.isEmpty)
        #expect(vm.phase == .answering)
        #expect(vm.progressText == "2 / 3")
        for _ in 0..<2 {
            vm.input = "1"
            vm.submit()
            vm.next()
        }
        #expect(vm.phase == .finished)
    }

    @Test("UT-VM-05・06")
    func quit() {
        let empty = make()
        empty.quit()
        #expect(empty.shouldDismiss)

        let vm = make()
        for _ in 0..<2 {
            vm.input = "1"
            vm.submit()
            vm.next()
        }
        vm.quit()
        #expect(vm.phase == .finished)
        #expect(vm.outcomes.count == 2)
        #expect(!vm.shouldDismiss)
    }

    @Test("UT-VM-07")
    func saveFailure() {
        let vm = make(FailingRecorder())
        vm.input = "62"
        vm.submit()
        #expect(vm.saveFailed)
        #expect(vm.phase == .answered(correct: true))
    }

    @Test("UT-VM-08")
    func empty() {
        #expect(make(questions: []).phase == .empty)
    }
}

@MainActor
struct OtherViewModelTests {
    @Test("UT-VM-09〜11")
    func cidr() {
        let vm = CIDRCalculatorViewModel()
        vm.paste("192.168.10.77/26")
        #expect(vm.addressText == "192.168.10.77")
        #expect(vm.prefixText == "26")

        vm.prefixText = "32"
        vm.stepPrefix(+1)
        #expect(vm.prefixText == "32")
        vm.prefixText = "0"
        vm.stepPrefix(-1)
        #expect(vm.prefixText == "0")

        let blank = CIDRCalculatorViewModel()
        #expect(blank.result == nil)
        blank.addressText = "192.168.10.77"
        #expect(blank.result == nil)
        blank.prefixText = "33"
        #expect(blank.result == .failure(.prefixRange(33)))
    }

    @Test("UT-VM-12")
    func rowLimits() {
        let vlsm = VLSMViewModel()
        while vlsm.canAddRow { vlsm.addRow() }
        #expect(vlsm.rows.count == 50)
        vlsm.addRow()
        #expect(vlsm.rows.count == 50)

        let summary = RouteSummaryViewModel()
        while summary.canAddRow { summary.addRow() }
        #expect(summary.rows.count == 32)
        summary.addRow()
        #expect(summary.rows.count == 32)
    }

    @Test("UT-VM-13")
    func percentText() {
        #expect(StatsViewModel.percentText(CategoryStats(answered: 8, correct: 1)) == "13%")
        #expect(StatsViewModel.percentText(CategoryStats(answered: 3, correct: 2)) == "67%")
        #expect(StatsViewModel.percentText(CategoryStats(answered: 0, correct: 0)) == "まだ回答していません")
    }

    @Test("UT-VM-14")
    func home() {
        let db = InMemoryStore()
        db.insertRecord("net-fund-0001", due: TestSupport.date(2026, 10, 17))
        db.insertRecord("net-fund-0002", due: TestSupport.date(2026, 10, 18))
        db.insertRecord("net-fund-0003", due: TestSupport.date(2026, 10, 19))
        db.insertLog("net-fund-0001", correct: true, at: TestSupport.day1)
        db.insertLog("net-fund-0002", correct: false, at: TestSupport.day1)
        let vm = HomeViewModel(store: db.store, now: { TestSupport.day1 })
        vm.refresh()
        #expect(vm.dueToday == 2)
        #expect(vm.answeredToday == 2)
    }

    @Test("UT-VM-15")
    func notes() {
        let split = SubnetSplitViewModel()
        split.network = NetworkInput(addressText: "192.168.10.0", prefixText: "24")
        split.numberText = "5"
        #expect(split.roundedNote == "5 分割 → 8 分割になります")

        let radix = RadixViewModel()
        radix.input = "0xFFFFFFC0"
        #expect(radix.detectedText == "16 進として読みました")
    }
}
