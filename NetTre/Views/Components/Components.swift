import SwiftUI
import UIKit

// MARK: - 大きなボタン（高さ 56pt 以上。NFR-01）

struct PrimaryButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, prominent: prominent)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Constants.minTapHeight)
                .foregroundStyle(prominent ? Color.white : Color.accentColor)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(prominent ? Color.accentColor : Color.accentColor.opacity(0.12))
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - コピーしました（FR-24）

@Observable
final class CopyToastModel {
    /// 表示する秒数。UI テストでは操作の遅れで見落とさないよう長くする（AppModel）
    static var displayDuration = Constants.copyToastDuration

    private(set) var visible = false
    private var token = 0

    func copy(_ value: String) {
        UIPasteboard.general.string = value
        visible = true
        token += 1
        let current = token
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.displayDuration) { [weak self] in
            guard let self, self.token == current else { return }
            self.visible = false
        }
    }
}

struct CopyToastModifier: ViewModifier {
    let model: CopyToastModel

    func body(content: Content) -> some View {
        content
            .environment(model)
            .overlay(alignment: .bottom) {
                if model.visible {
                    Text("コピーしました")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.opacity)
                        .accessibilityIdentifier("copyToast")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.visible)
    }
}

extension View {
    func copyToast(_ model: CopyToastModel) -> some View { modifier(CopyToastModifier(model: model)) }

    /// 数字のキーボードには閉じるキーがないため、キーボードの上に「閉じる」を置く
    func keyboardCloseButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("keyboardCloseButton")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - 結果の 1 行（値は等幅。右にコピー）

struct ResultRow: View {
    let label: String
    let value: String
    var copyValue: String?
    var identifier: String?
    @Environment(CopyToastModel.self) private var toast

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(minWidth: 110, alignment: .leading)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                toast.copy(copyValue ?? value)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(label)をコピー")
            .accessibilityIdentifier("copy-\(identifier ?? label)")
        }
        .contentShape(Rectangle())
        .onLongPressGesture { toast.copy(copyValue ?? value) }
    }
}

// MARK: - 誤りの表示

struct ErrorText: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "xmark.circle")
            .font(.footnote)
            .foregroundStyle(.red)
            .accessibilityIdentifier("inputError")
    }
}

// MARK: - 解き方（折りたたみ。FR-22）

struct StepsDisclosure: View {
    let steps: [String]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup("解き方", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    Text("\(i + 1). \(step)")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 4)
        }
        .accessibilityIdentifier("steps")
    }
}

// MARK: - IP アドレスとプレフィックス長の欄（S-08〜S-11 で共通）

struct NetworkInputFields: View {
    @Binding var input: NetworkInput
    var showsStepper = true
    var compact = false
    var identifier = "network"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if compact {
                HStack {
                    addressField
                    Text("/").foregroundStyle(.secondary)
                    prefixField.frame(maxWidth: 110)
                }
            } else {
                Text("IP アドレス").font(.subheadline).foregroundStyle(.secondary)
                addressField
                Text("プレフィックス長またはマスク").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    prefixField
                    if showsStepper {
                        Button { input.stepPrefix(-1) } label: {
                            Image(systemName: "minus").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("プレフィックス長を 1 減らす")
                        .accessibilityIdentifier("\(identifier)-prefixMinus")
                        Button { input.stepPrefix(1) } label: {
                            Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("プレフィックス長を 1 増やす")
                        .accessibilityIdentifier("\(identifier)-prefixPlus")
                    }
                }
            }
            if let e = input.addressError {
                ErrorText(message: e.message)
            } else if let e = input.prefixError {
                ErrorText(message: e.message)
            }
        }
    }

    private var addressField: some View {
        TextField("192.168.10.77", text: $input.addressText)
            .keyboardType(.decimalPad)
            .font(.body.monospaced())
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("IP アドレス")
            .accessibilityIdentifier("\(identifier)-address")
            .onChange(of: input.addressText) { _, new in
                // 「/26」付きや「マスク」付きを貼り付けたら 2 つの欄に分ける
                if new.contains("/") || new.contains("／") || new.trimmingCharacters(in: .whitespaces).contains(" ") {
                    input.paste(new)
                }
            }
    }

    private var prefixField: some View {
        TextField("26", text: $input.prefixText)
            .keyboardType(.decimalPad)
            .font(.body.monospaced())
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("プレフィックス長")
            .accessibilityIdentifier("\(identifier)-prefix")
    }
}

// MARK: - Markdown の解説

struct MarkdownText: View {
    let source: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(source)
        }
    }
}
