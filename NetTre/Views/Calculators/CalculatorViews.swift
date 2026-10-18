import SwiftUI

/// S-07 計算機メニュー
struct CalculatorMenuView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.calculators
        List {
            row("CIDR 計算", "ネットワーク・範囲・ホスト数", id: "calc-cidr") {
                CIDRCalculatorView(viewModel: store.cidr)
            }
            row("サブネット分割", "分割数・ホスト数で等分", id: "calc-split") {
                SubnetSplitView(viewModel: store.split)
            }
            row("VLSM 設計", "用途ごとに無駄なく割り当て", id: "calc-vlsm") {
                VLSMView(viewModel: store.vlsm)
            }
            row("経路集約", "複数のネットワークをまとめる", id: "calc-summary") {
                RouteSummaryView(viewModel: store.summary)
            }
            row("進数変換", "10 進・2 進・16 進", id: "calc-radix") {
                RadixView(viewModel: store.radix)
            }
        }
        .navigationTitle("計算")
    }

    private func row(_ title: String, _ detail: String, id: String,
                     @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(minHeight: Constants.minTapHeight, alignment: .leading)
        }
        .accessibilityIdentifier(id)
    }
}

// MARK: - S-08 CIDR 計算

struct CIDRCalculatorView: View {
    @Bindable var viewModel: CIDRCalculatorViewModel
    var presentedAsSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var toast = CopyToastModel()

    var body: some View {
        Form {
            Section {
                NetworkInputFields(input: $viewModel.network, identifier: "cidr")
            }
            if case let .success(r) = viewModel.result {
                let s = r.subnet
                Section("結果") {
                    ResultRow(label: "ネットワーク", value: s.network.description, identifier: "network")
                    ResultRow(label: "ブロードキャスト", value: s.broadcast.description, identifier: "broadcast")
                    ResultRow(label: "サブネットマスク", value: s.mask.description, identifier: "mask")
                    ResultRow(label: "ワイルドカード", value: s.wildcard.description, identifier: "wildcard")
                    ResultRow(label: "ホストの範囲", value: "\(s.firstHost) 〜 \(s.lastHost)", identifier: "range")
                    ResultRow(label: "使えるホスト数", value: CIDRCalculatorViewModel.hostsText(s),
                              copyValue: String(s.usableHosts), identifier: "hosts")
                    ResultRow(label: "種別", value: r.kind.displayName, identifier: "kind")
                }
                Section("2 進数") {
                    BinaryView(address: s.address, prefix: s.prefix)
                }
                Section {
                    StepsDisclosure(steps: r.steps)
                }
            }
        }
        .navigationTitle("CIDR 計算")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentedAsSheet {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }.accessibilityIdentifier("closeSheetButton")
                }
            }
        }
        .keyboardCloseButton()
        .copyToast(toast)
    }
}

/// ネットワーク部とホスト部の境目に区切りを入れ、ホスト部を薄くする
private struct BinaryView: View {
    let address: IPv4
    let prefix: Int

    var body: some View {
        let bits = address.binaryString.filter { $0 != "." }.map(String.init)
        var text = Text("")
        for (i, bit) in bits.enumerated() {
            if i > 0, i % 8 == 0 { text = text + Text(".") }
            if i == prefix, prefix > 0 { text = text + Text("|").foregroundStyle(.orange) }
            text = text + Text(bit).foregroundStyle(i < prefix ? Color.primary : Color.secondary)
        }
        return text
            .font(.footnote.monospaced())
            .minimumScaleFactor(0.6)
            .lineLimit(2)
    }
}

// MARK: - S-09 サブネット分割

struct SubnetSplitView: View {
    @Bindable var viewModel: SubnetSplitViewModel
    @State private var toast = CopyToastModel()

    var body: some View {
        Form {
            Section("ネットワーク") {
                NetworkInputFields(input: $viewModel.network, showsStepper: false, compact: true, identifier: "split")
            }
            Section("分け方") {
                Picker("分け方", selection: $viewModel.kind) {
                    ForEach(SubnetSplitViewModel.Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("splitKind")
                TextField(viewModel.kind == .count ? "分割数（例 4）" : "1 サブネットのホスト数（例 50）",
                          text: $viewModel.numberText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("splitNumber")
            }
            switch viewModel.result {
            case let .failure(e):
                Section { ErrorText(message: e.message) }
            case let .success(r):
                Section {
                    if let summary = viewModel.summaryText {
                        Text(summary).font(.headline).accessibilityIdentifier("splitSummary")
                    }
                    if let note = viewModel.roundedNote {
                        Text(note).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("roundedNote")
                    }
                    if let note = viewModel.truncationNote {
                        Text(note).font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("truncationNote")
                    }
                }
                Section("一覧") {
                    ForEach(Array(r.subnets.enumerated()), id: \.offset) { i, s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(i + 1)  \(s.cidrString)").font(.body.monospaced())
                            Text("\(s.firstHost) 〜 \(s.lastHost)  BC \(s.broadcast)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture { toast.copy(s.cidrString) }
                        .accessibilityIdentifier("splitRow")
                    }
                }
                if let parent = viewModel.parent {
                    Section { StepsDisclosure(steps: CalculationSteps.split(r, parent: parent)) }
                }
            case nil:
                EmptyView()
            }
        }
        .navigationTitle("サブネット分割")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardCloseButton()
        .copyToast(toast)
    }
}

// MARK: - S-10 VLSM 設計

struct VLSMView: View {
    @Bindable var viewModel: VLSMViewModel
    @State private var toast = CopyToastModel()

    var body: some View {
        Form {
            Section("親ネットワーク") {
                NetworkInputFields(input: $viewModel.network, showsStepper: false, compact: true, identifier: "vlsm")
            }
            Section("用途と必要ホスト数") {
                ForEach($viewModel.rows) { $row in
                    HStack {
                        TextField("用途（例 営業部）", text: $row.name)
                            .textFieldStyle(.roundedBorder)
                        TextField("台数", text: $row.hostsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 90)
                        Button {
                            viewModel.removeRow(id: row.id)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("この用途を消す")
                    }
                }
                Button {
                    viewModel.addRow()
                } label: {
                    Label("用途を追加", systemImage: "plus")
                }
                .disabled(!viewModel.canAddRow)
                .accessibilityIdentifier("addVLSMRow")
                if !viewModel.canAddRow {
                    Text("用途は \(Constants.vlsmMaxRequirements) 件までです").font(.footnote).foregroundStyle(.secondary)
                }
            }
            switch viewModel.result {
            case let .failure(e):
                Section { ErrorText(message: e.message) }
            case let .success(plan):
                Section("割り当て") {
                    ForEach(plan.allocations, id: \.requirement.id) { a in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(a.requirement.name)
                                Spacer()
                                Text("\(a.subnet.usableHosts.grouped) / \(a.requirement.hosts)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(a.subnet.cidrString).font(.body.monospaced())
                            Text("\(a.subnet.firstHost) 〜 \(a.subnet.lastHost)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture { toast.copy(a.subnet.cidrString) }
                    }
                }
                Section("空き") {
                    if plan.freeBlocks.isEmpty {
                        Text("ありません")
                    } else {
                        ForEach(plan.freeBlocks, id: \.self) { Text($0.cidrString).font(.body.monospaced()) }
                    }
                }
                Section { StepsDisclosure(steps: CalculationSteps.vlsm(plan)) }
            case nil:
                EmptyView()
            }
        }
        .navigationTitle("VLSM 設計")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardCloseButton()
        .copyToast(toast)
    }
}

// MARK: - S-11 経路集約

struct RouteSummaryView: View {
    @Bindable var viewModel: RouteSummaryViewModel
    @State private var toast = CopyToastModel()

    var body: some View {
        Form {
            Section("ネットワーク") {
                ForEach($viewModel.rows) { $row in
                    HStack {
                        NetworkInputFields(input: $row.network, showsStepper: false, compact: true, identifier: "summary")
                        Button {
                            viewModel.removeRow(id: row.id)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("このネットワークを消す")
                    }
                }
                Button {
                    viewModel.addRow()
                } label: {
                    Label("ネットワークを追加", systemImage: "plus")
                }
                .disabled(!viewModel.canAddRow)
                .accessibilityIdentifier("addSummaryRow")
                if let note = viewModel.hostBitsNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
            switch viewModel.result {
            case let .failure(e):
                Section { ErrorText(message: e.message) }
            case let .success(r):
                Section("集約ルート") {
                    ResultRow(label: "集約ルート", value: r.route.cidrString, identifier: "route")
                }
                Section("余分に含まれる範囲") {
                    if let text = viewModel.extraText {
                        Text(text)
                    } else {
                        ForEach(r.extraRanges, id: \.self) { Text($0.cidrString).font(.body.monospaced()) }
                        if r.extraTruncated {
                            Text("先頭 \(Constants.extraRangesDisplayLimit) 件を表示").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section { StepsDisclosure(steps: CalculationSteps.summary(r)) }
            case nil:
                EmptyView()
            }
        }
        .navigationTitle("経路集約")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardCloseButton()
        .copyToast(toast)
    }
}

// MARK: - S-12 進数変換

struct RadixView: View {
    @Bindable var viewModel: RadixViewModel
    @State private var toast = CopyToastModel()

    var body: some View {
        Form {
            Section {
                TextField("255.255.255.192", text: $viewModel.input)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("radixInput")
            }
            switch viewModel.result {
            case let .failure(e):
                Section { ErrorText(message: e.message) }
            case let .success(r):
                Section {
                    if let detected = viewModel.detectedText {
                        Text(detected).font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("radixDetected")
                    }
                    ResultRow(label: "10 進", value: r.value.description, identifier: "dec")
                    ResultRow(label: "2 進", value: r.value.binaryString, identifier: "bin")
                    ResultRow(label: "16 進", value: r.value.hexString, identifier: "hex")
                }
            case nil:
                EmptyView()
            }
        }
        .navigationTitle("進数変換")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardCloseButton()
        .copyToast(toast)
    }
}
