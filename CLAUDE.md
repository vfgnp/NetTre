# ネトレ（NetTre）— プロジェクト引き継ぎ

## 概要
CCNAなどネットワーク資格向けの、スマホ特化の問題演習iOSアプリ。
Ping-t がスマホで使いにくい（PCレイアウト）という不満が出発点。
目標は「Ping-tレベルの問題演習を、通勤中に片手で」。App Store で公開する。

- アプリ名（仮）：ネトレ - ネットワーク資格ドリル
- サブタイトル（仮）：通勤1問、CCNA対策をスキマ時間で
- 名前は未確定。App Store Connect での仮登録と J-PlatPat の商標検索がまだ。

## 絶対に守ること（コンテンツ・法務）
- Ping-t・市販参考書の問題や解説を転載・改変して使わない（著作権）。
- 実際の試験問題の再現（ブレインダンプ）は禁止（Cisco の受験規約に違反する）。
- 「CCNA」「Cisco」はアプリ名の先頭に置かない。サブタイトルや説明文で「CCNA対策」のように説明的に使う。
- アプリ名に「Ping」を含めない（Ping-t との混同を避ける）。
- 問題はすべてオリジナル。AIで下書きした問題も、技術的な正確さを人が確認してから収録する。

## プロダクト方針
- 1問30秒、片手で操作できるUI
- 間隔反復（SM-2 の簡略版）で、間違えた問題を翌日に、正解した問題は間隔を広げて再出題
- 自動生成できる問題（サブネット計算 → 今後 ACL・ワイルドカードマスクなど）で問題数を確保する
- MVP：サブネット自動出題 ＋ 手書き問題を少し。有料化は問題数がそろってから（買い切り or 分野別課金）

## 現在のファイル
| パス | 内容 |
|---|---|
| project.yml | XcodeGen の定義（`xcodegen generate` で NetTre.xcodeproj を作る。.xcodeproj は git に入れない） |
| NetTre/App/ | `NetTreApp`・`RootTabView`・`AppModel`（共有の状態と UI テスト用の起動引数）・`AppEnvironment`・`Constants` |
| NetTre/Models/ | `Question`・`Domain`・`Difficulty`、`ReviewState`（間隔反復）、SwiftData の `ReviewRecord`・`AnswerLog` |
| NetTre/Generators/SubnetQuestionGenerator.swift | サブネット問題 5 種の自動生成、ID の分解（`question(fromId:)`・`subnet(fromId:)`） |
| NetTre/Calculators/ | IPv4・Subnet・SeededRNG、入力の読み取り、CIDR／分割／VLSM／集約／進数変換、解き方の文 |
| NetTre/Services/ | `AnswerNormalizer`・`QuestionRepository`・`ReviewStore`（+`ReviewRecording`）・`SessionBuilder` |
| NetTre/ViewModels/ | 学習・ホーム・分野選択・成績・計算機 5 つの ViewModel |
| NetTre/Views/ | S-01〜S-12 の画面と共通部品 |
| NetTre/Resources/ | `questions.json`（手書き問題 3 問）、`questions_uitest.json`（UI テスト用 20 問。Release には入れない）、`PrivacyInfo.xcprivacy` |
| NetTreTests/ | Swift Testing の単体テスト（05）と結合テスト（06 の自動分）。`Fixtures/` は照合用データ |
| NetTreUITests/ | XCUITest（06 の UI テスト分） |
| scripts/gen_fixtures.py | 照合用データを Python の ipaddress で作る |
| scripts/check_nfr.sh | IT-NF-02 の検査（権限・通信・外部パッケージ・プライバシーマニフェスト） |
| docs/ | 設計文書（下の「設計文書と進め方」を参照） |
| handoff/ | 引き継ぎ時の zip と START_PROMPT.md（記録として保管。編集しない） |

## ビルドとテスト
- Xcode はこの Mac の `/Users/watanabekouzou/Desktop/Xcode.app`（16.2）。`xcode-select` は変えず、`DEVELOPER_DIR` で指定する。
  ```
  xcodegen generate
  export DEVELOPER_DIR=/Users/watanabekouzou/Desktop/Xcode.app/Contents/Developer
  xcodebuild test -scheme NetTre -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath build/DD CODE_SIGNING_ALLOWED=NO
  ```
- Swift Testing（Xcode 16.2）では `#expect(xs.allSatisfy(...))` のように rethrows の関数を直接書くとマクロが展開できない。`#expect(check(...))` で包む（`NetTreTests/TestSupport.swift`）。

## 設計文書と進め方
docs/ に V字モデルで文書を置く。

| ファイル | 状態 |
|---|---|
| 01_要件定義書.md | v1.3 確定（2026-10-18） |
| 02_基本設計書.md | v1.4 確定（2026-10-18） |
| 03_画面仕様書.md | v1.2（2026-10-18。テストレビューを受けた小改訂） |
| 04_詳細設計書.md | v1.2（2026-10-18。テストのための仕組みを §12 に追加） |
| 05_詳細テスト仕様書.md | v0.4（第三者レビュー 3 回済み。単体テスト） |
| 06_基本設計テスト仕様書.md | v0.4（第三者レビュー 3 回済み。結合テスト・UI テスト） |
| 07_要件定義テスト仕様書.md | v0.4（第三者レビュー 3 回済み。実機での総合・受け入れテスト） |

- **要件定義書・基本設計書・画面仕様書の3つをユーザーが完成と認めるまで、詳細設計・テスト仕様書・実装（Xcode プロジェクト作成を含む）に進まない。**（ユーザーの指示、2026-10-18）→ 2026-10-18 に 3 文書とも承認済み。詳細設計に着手
- 文書中の「【要確認】」は仮の決定。確定したら印を外し、版を上げる。

### 設計上の決まり
- 問題IDの形式：手書きは `<domain略>-<連番>`（例 `net-fund-0001`）、自動生成は `gen-subnet-<type>-<difficulty>-<seed>`（difficulty は 1〜3）
  （基本設計 D1 で採用。引き継ぎ時の `SubnetQuestionGenerator` はまだ旧形式なので実装工程で直す）
- 自動生成問題は seed から完全に再現できる → 学習履歴には seed（ID）だけ保存すればよい
- `ReviewState` は問題本体と分けて端末内に保存する（SwiftData に確定。基本設計 §5.2）
- `version` は問題を修正したら上げる。履歴の扱いに使う予定
- domain は CCNA 200-301 の分野に合わせる：network-fundamentals / network-access / ip-connectivity / ip-services / security-fundamentals / automation-programmability

## 検証の状況
- サブネットの計算式は Python の ipaddress で作った照合用データ（CIDR 2 万件・範囲 2,000 件・集約 2,000 件）と Swift の実装を照合して一致（UT-SN-08・UT-CB-05・UT-RT-07）。
- 2026-10-18 に初回の実装を終え、ビルドが通った。単体＋結合テスト（Swift Testing）125 件はすべて合格。
- UI テスト（XCUITest）17 件は iPhone 16 シミュレーターで合格。06 のうち IT-UI-05 の文字サイズ（IT-NF-05）・起動時間（IT-NF-01、実機）は未自動化。

## 既知の問題・TODO
- **手書き問題が 3 問しかない**（`questions.json`）。MVP の 30 問は、人が技術的な正確さを確認してから収録する（AI の下書きをそのまま入れない）。
- プライバシーポリシー・お問い合わせの URL が未定（要件定義 U-06）。決まるまで設定画面は「準備中」と出す（`AppLinks`）。
- アプリのアイコン（Assets.xcassets）が未作成。
- 07（総合・受け入れテスト）は実機での手動テスト。未実施。

## 次にやること（優先順）
1. 手書き問題を 30 問に増やす（人の確認つき）
2. 実機で 07 の総合テストを行う。アイコンと URL を決める
3. App Store Connect での名前の仮登録、J-PlatPat の商標検索
