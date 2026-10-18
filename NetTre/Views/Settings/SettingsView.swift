import SwiftUI

/// 外部へのリンク。URL は提出前に決める（要件定義 U-06）。nil の間は「準備中」と出す
enum AppLinks {
    static let privacyPolicy: URL? = nil
    static let support: URL? = nil
}

/// S-06 設定
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmDelete = false
    @State private var confirmRebuild = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("データ") {
                if model.databaseFailed {
                    Button("履歴を消して作り直す", role: .destructive) { confirmRebuild = true }
                        .accessibilityIdentifier("rebuildButton")
                }
                Button("学習履歴を削除する", role: .destructive) { confirmDelete = true }
                    .accessibilityIdentifier("deleteHistoryButton")
                if let errorMessage {
                    ErrorText(message: errorMessage)
                }
            }
            Section("このアプリについて") {
                linkRow("プライバシーポリシー", AppLinks.privacyPolicy)
                linkRow("お問い合わせ", AppLinks.support)
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(versionText).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("設定")
        .alert("学習履歴をすべて削除しますか？", isPresented: $confirmDelete) {
            Button("削除する", role: .destructive) { run { try model.deleteAll() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
        .alert("学習履歴を消して作り直しますか？", isPresented: $confirmRebuild) {
            Button("作り直す", role: .destructive) { run { try model.rebuildDatabase() } }
            Button("キャンセル", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func linkRow(_ title: String, _ url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("準備中").foregroundStyle(.secondary)
            }
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = "学習履歴を変更できませんでした"
        }
    }
}
