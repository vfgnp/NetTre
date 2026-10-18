import XCTest

/// App Store 用のスクリーンショットを撮る。環境変数 SCREENSHOT_DIR があるときだけ動く
/// （xcodebuild に TEST_RUNNER_SCREENSHOT_DIR=<保存先> を渡す）
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!
    var directory = ""

    override func setUpWithError() throws {
        directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? ""
        try XCTSkipIf(directory.isEmpty, "SCREENSHOT_DIR がないので撮らない")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest", "-uitestDemoHistory"]
        app.launch()
    }

    func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func waitFor(_ id: String) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: 5), "\(id) が出ない")
        return e
    }

    func shot(_ name: String) {
        sleep(1)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        XCTAssertNoThrow(try data.write(to: url))
    }

    func closeKeyboard() {
        let close = app.buttons["keyboardCloseButton"]
        if close.exists && close.isHittable { close.tap() }
    }

    /// "192.168.10.77/26 が所属する…" からネットワークアドレスを計算する
    func networkAnswer(_ stem: String) -> String? {
        guard let cidr = stem.split(separator: " ").first else { return nil }
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let prefix = UInt32(parts[1]) else { return nil }
        let octets = parts[0].split(separator: ".").compactMap { UInt32($0) }
        guard octets.count == 4 else { return nil }
        let value = octets.reduce(0) { $0 << 8 | $1 }
        let mask: UInt32 = prefix == 0 ? 0 : UInt32.max << (32 - prefix)
        let n = value & mask
        return [24, 16, 8, 0].map { String((n >> UInt32($0)) & 0xFF) }.joined(separator: ".")
    }

    func testScreenshots() {
        // 1・2 出題と回答後（ネットワークアドレスの問題を正解する）
        app.tabBars.buttons["学習"].tap()
        waitFor("chooseDomainButton").tap()
        waitFor("startDrillButton").tap()
        var answered = false
        for _ in 0..<20 {
            let stem = waitFor("questionStem").label
            if stem.contains("ネットワークアドレス"), let answer = networkAnswer(stem) {
                waitFor("answerField").typeText(answer)
                shot("01_question")
                element("submitButton").tap()
                _ = waitFor("verdict")
                shot("02_answered")
                answered = true
                break
            }
            waitFor("answerField").typeText("0")
            element("submitButton").tap()
            waitFor("nextButton").tap()
            if element("againButton").exists { element("againButton").tap() }
        }
        XCTAssertTrue(answered)
        element("quitButton").tap()
        waitFor("homeButton").tap()
        // 学習タブは分野選択のままなので、ホームまで戻る
        app.navigationBars.buttons.firstMatch.tap()

        // 3 CIDR 計算
        app.tabBars.buttons["計算"].tap()
        waitFor("calc-cidr").tap()
        let address = waitFor("cidr-address")
        address.tap()
        address.typeText("192.168.10.77")
        let prefix = element("cidr-prefix")
        prefix.tap()
        prefix.typeText("26")
        closeKeyboard()
        app.swipeUp()
        if app.buttons["解き方"].exists { app.buttons["解き方"].tap() }
        app.swipeDown()
        shot("03_cidr")
        app.navigationBars.buttons.firstMatch.tap()

        // 4 VLSM 設計
        waitFor("calc-vlsm").tap()
        let parent = waitFor("vlsm-address")
        parent.tap()
        parent.typeText("192.168.10.0")
        element("vlsm-prefix").tap()
        element("vlsm-prefix").typeText("24")
        let rows = [("営業部", "50"), ("開発部", "25"), ("拠点間リンク", "2")]
        for (i, row) in rows.enumerated() {
            if i >= 2 { element("addVLSMRow").tap() }
            let names = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "用途（例 営業部）"))
            let hosts = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "台数"))
            names.element(boundBy: i).tap()
            names.element(boundBy: i).typeText(row.0)
            hosts.element(boundBy: i).tap()
            hosts.element(boundBy: i).typeText(row.1)
        }
        closeKeyboard()
        shot("04_vlsm")
        app.navigationBars.buttons.firstMatch.tap()

        // 5 成績・6 ホーム（見本の履歴）
        app.tabBars.buttons["成績"].tap()
        _ = waitFor("statsTotal")
        shot("05_stats")
        app.tabBars.buttons["学習"].tap()
        _ = waitFor("answeredToday")
        shot("06_home")
    }
}
