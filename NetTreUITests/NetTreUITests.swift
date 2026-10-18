import XCTest

/// 06 基本設計テストのうち、XCUITest で自動化するもの
final class NetTreUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - 補助

    func launch(_ extra: [String] = []) {
        app.launchArguments = ["-uitest"] + extra
        app.launch()
    }

    func tab(_ name: String) {
        // 計算機の数字キーボードがタブバーを隠すので、出ていれば閉じる
        let close = app.buttons["keyboardCloseButton"]
        if close.exists && close.isHittable { close.tap() }
        app.tabBars.buttons[name].tap()
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func waitFor(_ id: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(id) が出ない", file: file, line: line)
        return e
    }

    /// 「0」を入力して回答し、次へ進む（全問不正解にする）
    func answerZero(andNext: Bool = true) {
        let field = waitFor("answerField")
        field.typeText("0")
        element("submitButton").tap()
        if andNext { waitFor("nextButton").tap() }
    }

    func startMixed() {
        tab("学習")
        waitFor("startButton").tap()
        _ = waitFor("answerField")
    }

    // MARK: - IT-UI-01 タブ

    func testTabs() {
        launch()
        XCTAssertTrue(waitFor("startButton").exists)
        tab("計算")
        XCTAssertTrue(waitFor("calc-cidr").exists)
        tab("成績")
        XCTAssertTrue(waitFor("statsEmpty").exists)
        tab("設定")
        XCTAssertTrue(waitFor("deleteHistoryButton").exists)
    }

    // MARK: - IT-UI-02・03・NF-06 学習の一連の流れ

    func testFullSession() {
        launch()
        XCTAssertEqual(waitFor("answeredToday").label, "0 問")
        startMixed()
        // 出題中はタブバーを出さない
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        // IT-UI-03 入力欄が選ばれ、キーボードが出ている。空では押せない
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(element("submitButton").isEnabled)
        // IT-NF-06 アクセシビリティ
        XCTAssertEqual(element("answerField").label, "回答")
        XCTAssertEqual(element("quitButton").label, "学習を中断する")

        for i in 1...10 {
            XCTAssertEqual(waitFor("progressText").label, "\(i) / 10")
            answerZero(andNext: false)
            let next = waitFor("nextButton")
            XCTAssertEqual(next.label, i == 10 ? "結果を見る" : "次へ")
            next.tap()
        }
        XCTAssertEqual(waitFor("resultScore").label, "0 / 10 問 正解")
        element("homeButton").tap()
        XCTAssertEqual(waitFor("answeredToday").label, "10 問")
    }

    // MARK: - IT-UI-04 キーボードの種類

    func testKeyboardKinds() {
        launch()
        tab("学習")
        waitFor("chooseDomainButton").tap()
        waitFor("startDrillButton").tap()
        var sawHostCount = false
        var sawAddress = false
        for _ in 0..<30 where !(sawHostCount && sawAddress) {
            if element("againButton").exists { element("againButton").tap() }
            let stem = waitFor("questionStem").label
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
            let hasDot = app.keyboards.keys["."].exists
            if stem.contains("ホスト数") {
                XCTAssertFalse(hasDot, "ホスト数の問題で「.」がある")
                sawHostCount = true
            } else if stem.contains("アドレス") {
                XCTAssertTrue(hasDot, "アドレスの問題で「.」がない")
                sawAddress = true
            }
            answerZero()
        }
        XCTAssertTrue(sawHostCount && sawAddress)
    }

    // MARK: - IT-UI-05 難易度の記憶

    func testDifficultyRemembered() {
        launch()
        tab("学習")
        waitFor("chooseDomainButton").tap()
        let picker = waitFor("difficultyPicker")
        picker.buttons["応用"].tap()
        element("startDrillButton").tap()
        XCTAssertTrue(waitFor("answerField").exists)
        XCTAssertTrue(app.staticTexts["サブネット計算・応用"].exists)
        element("quitButton").tap()
        XCTAssertTrue(waitFor("difficultyPicker").buttons["応用"].isSelected)

        app.terminate()
        app.launchArguments = ["-uitest", "-uitestKeepDefaults"]
        app.launch()
        tab("学習")
        waitFor("chooseDomainButton").tap()
        XCTAssertTrue(waitFor("difficultyPicker").buttons["応用"].isSelected)
    }

    // MARK: - IT-UI-06 中断

    func testQuit() {
        launch()
        startMixed()
        element("quitButton").tap()
        XCTAssertTrue(waitFor("startButton").exists)

        startMixed()
        for _ in 0..<3 { answerZero() }
        element("quitButton").tap()
        XCTAssertEqual(waitFor("resultScore").label, "0 / 3 問 正解")
    }

    // MARK: - IT-UI-07 結果画面の操作

    func testResultActions() {
        launch()
        startMixed()
        for _ in 0..<3 { answerZero() }
        element("quitButton").tap()
        waitFor("wrongQuestion").tap()
        XCTAssertTrue(waitFor("verdict").exists)
        app.navigationBars.buttons.firstMatch.tap()
        waitFor("againButton").tap()
        XCTAssertEqual(waitFor("progressText").label, "1 / 10")
    }

    // MARK: - IT-UI-08 復習の印（保存して翌日に起動し直す）

    func testReviewBadgeNextDay() {
        app.launchArguments = ["-uitest", "-uitestPersistentStore", "-uitestResetStore"]
        app.launch()
        startMixed()
        XCTAssertFalse(element("reviewBadge").exists)
        answerZero()
        element("quitButton").tap()
        app.terminate()

        app.launchArguments = ["-uitest", "-uitestPersistentStore", "-uitestDay", "2"]
        app.launch()
        startMixed()
        XCTAssertTrue(waitFor("reviewBadge").exists)
    }

    // MARK: - IT-UI-09 計算機で確かめる

    func testVerifyWithCalculator() {
        launch()
        tab("学習")
        waitFor("chooseDomainButton").tap()
        waitFor("startDrillButton").tap()
        let stem = waitFor("questionStem").label
        answerZero(andNext: false)
        waitFor("verifyButton").tap()
        let address = waitFor("cidr-address")
        let value = address.value as? String ?? ""
        XCTAssertFalse(value.isEmpty)
        if stem.contains("/") && !stem.hasPrefix("/") {
            XCTAssertTrue(stem.hasPrefix(value), "問題のアドレスが入っていない: \(stem) / \(value)")
        }
        element("closeSheetButton").tap()
        XCTAssertTrue(waitFor("verdict").exists)
    }

    // MARK: - IT-UI-10 計算機の画面

    func testCalculatorScreens() {
        launch()
        tab("計算")
        for (id, title) in [("calc-cidr", "CIDR 計算"), ("calc-split", "サブネット分割"), ("calc-vlsm", "VLSM 設計"),
                            ("calc-summary", "経路集約"), ("calc-radix", "進数変換")] {
            waitFor(id).tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - IT-UI-11 コピー ／ IT-CA-10 入力を残す

    func testCopyAndKeepInput() {
        launch()
        tab("計算")
        waitFor("calc-cidr").tap()
        let address = waitFor("cidr-address")
        address.tap()
        address.typeText("192.168.10.77")
        let prefix = element("cidr-prefix")
        prefix.tap()
        prefix.typeText("26")
        waitFor("copy-network").tap()
        XCTAssertTrue(waitFor("copyToast", timeout: 3).exists)

        tab("学習")
        tab("計算")
        XCTAssertEqual(waitFor("cidr-address").value as? String, "192.168.10.77")
        XCTAssertTrue(element("copy-network").exists)
    }

    // MARK: - IT-CA-11 シートの入力がタブ側に混ざらない

    func testSheetDoesNotChangeTab() {
        launch()
        tab("計算")
        waitFor("calc-cidr").tap()
        let address = waitFor("cidr-address")
        address.tap()
        address.typeText("8.8.8.8")

        tab("学習")
        waitFor("chooseDomainButton").tap()
        waitFor("startDrillButton").tap()
        answerZero(andNext: false)
        waitFor("verifyButton").tap()
        waitFor("closeSheetButton").tap()
        element("quitButton").tap()
        element("homeButton").tap()

        tab("計算")
        XCTAssertEqual(waitFor("cidr-address").value as? String, "8.8.8.8")
    }

    // MARK: - IT-UI-12 履歴の削除

    func testDeleteHistory() {
        launch()
        startMixed()
        answerZero()
        element("quitButton").tap()
        element("homeButton").tap()
        XCTAssertEqual(waitFor("answeredToday").label, "1 問")

        tab("設定")
        waitFor("deleteHistoryButton").tap()
        app.alerts.buttons["キャンセル"].tap()
        tab("学習")
        XCTAssertEqual(waitFor("answeredToday").label, "1 問")

        tab("設定")
        waitFor("deleteHistoryButton").tap()
        app.alerts.buttons["削除する"].tap()
        tab("学習")
        XCTAssertEqual(waitFor("answeredToday").label, "0 問")
        XCTAssertTrue(element("dueMessage").exists)
        tab("成績")
        XCTAssertTrue(waitFor("statsEmpty").exists)
    }

    // MARK: - IT-ER-01（UI）壊れた問題データ

    func testBrokenQuestions() {
        launch(["-uitestBrokenQuestions"])
        startMixed()
        XCTAssertTrue(element("questionStem").exists)
    }

    // MARK: - IT-ER-03 データベースが開けない

    func testDatabaseFailure() {
        launch(["-uitestPersistentStore", "-uitestFailModelContainer"])
        startMixed()
        answerZero()
        element("quitButton").tap()
        element("homeButton").tap()
        tab("設定")
        waitFor("rebuildButton").tap()
        app.alerts.buttons["作り直す"].tap()
        XCTAssertFalse(element("rebuildButton").waitForExistence(timeout: 1))
        app.terminate()

        launch(["-uitestPersistentStore"])
        tab("設定")
        XCTAssertTrue(waitFor("deleteHistoryButton").exists)
        XCTAssertFalse(element("rebuildButton").exists)
    }

    // MARK: - IT-ER-04 大きな分割

    func testLargeSplit() {
        launch()
        tab("計算")
        waitFor("calc-split").tap()
        let address = waitFor("split-address")
        address.tap()
        address.typeText("10.0.0.0")
        let prefix = element("split-prefix")
        prefix.tap()
        prefix.typeText("8")
        waitFor("splitKind").buttons["ホスト数"].tap()
        let number = element("splitNumber")
        number.tap()
        number.typeText("2")
        XCTAssertTrue(element("splitRow").waitForExistence(timeout: 1))
        XCTAssertTrue(element("truncationNote").exists)
        element("splitKind").buttons["分割数"].tap()
        XCTAssertTrue(element("roundedNote").waitForExistence(timeout: 1) || element("splitRow").exists)
    }

    // MARK: - IT-NF-03 強制終了しても回答が残る

    func testPersistAcrossRelaunch() {
        app.launchArguments = ["-uitest", "-uitestPersistentStore", "-uitestResetStore"]
        app.launch()
        startMixed()
        for _ in 0..<5 { answerZero() }
        app.terminate()

        app.launchArguments = ["-uitest", "-uitestPersistentStore"]
        app.launch()
        tab("成績")
        XCTAssertEqual(waitFor("statsTotal").label, "5 問")
    }

    // MARK: - IT-NF-07 ボタンの位置と高さ

    func testButtonPlacement() {
        launch()
        startMixed()
        let screen = app.windows.firstMatch.frame
        let submit = element("submitButton")
        XCTAssertGreaterThanOrEqual(submit.frame.height, 56)
        XCTAssertGreaterThan(submit.frame.midY, screen.midY)
        answerZero(andNext: false)
        let next = waitFor("nextButton")
        XCTAssertGreaterThanOrEqual(next.frame.height, 56)
        XCTAssertGreaterThan(next.frame.midY, screen.midY)
    }
}
