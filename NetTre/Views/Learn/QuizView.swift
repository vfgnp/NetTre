import SwiftUI

/// 出題（S-03）と結果（S-04）を同じカバーの中で切り替える
struct QuizFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let session: QuizSessionViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .empty:
                    EmptySessionView()
                case .finished:
                    SessionResultView(session: session)
                case .answering, .answered:
                    QuizView(session: session)
                }
            }
        }
        .onChange(of: session.shouldDismiss) { _, should in
            if should { dismiss() }
        }
    }
}

private struct EmptySessionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("この分野の問題はまだありません")
                .font(.headline)
            Spacer()
            Button("戻る") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

/// S-03 出題
struct QuizView: View {
    let session: QuizSessionViewModel
    @FocusState private var focused: Bool
    @State private var calculator: CIDRCalculatorViewModel?
    @State private var showSaveError = false

    var body: some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 12) {
            header
            if let question = session.current {
                if case let .answered(correct) = session.phase {
                    AnsweredDetail(question: question, correct: correct,
                                   input: session.lastOutcome?.input ?? "",
                                   onVerify: openCalculator)
                } else {
                    answering(question: question, input: $session.input)
                }
            }
        }
        .padding(.horizontal)
        .safeAreaInset(edge: .bottom) { bottomButton.padding() }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(trigger: session.phase) { _, new in
            if case let .answered(correct) = new { return correct ? .success : .error }
            return nil
        }
        .onAppear { focused = true }
        .onChange(of: session.index) { _, _ in focused = true }
        .onChange(of: session.phase) { _, new in
            if case .answered = new { focused = false }
        }
        .onChange(of: session.saveFailed) { _, failed in
            guard failed else { return }
            showSaveError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSaveError = false
                session.saveFailed = false
            }
        }
        .overlay(alignment: .top) {
            if showSaveError {
                Text("学習記録を保存できませんでした")
                    .font(.subheadline.bold())
                    .padding(10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 60)
                    .accessibilityIdentifier("saveError")
            }
        }
        .sheet(item: $calculator) { vm in
            NavigationStack {
                CIDRCalculatorView(viewModel: vm, presentedAsSheet: true)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(session.progressText)
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("progressText")
                HStack {
                    Button {
                        session.quit()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("学習を中断する")
                    .accessibilityIdentifier("quitButton")
                    Spacer()
                }
            }
            ProgressView(value: session.progress)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func answering(question: Question, input: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text("\(question.isGenerated ? "サブネット計算" : question.domain.displayName)・\(question.difficulty.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if session.isReview {
                Text("復習")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2), in: Capsule())
                    .accessibilityIdentifier("reviewBadge")
            }
        }
        ScrollView {
            Text(question.stem)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("questionStem")
        }
        Text("回答").font(.subheadline).foregroundStyle(.secondary)
        TextField("", text: input)
            .keyboardType(question.keyboard == .decimal ? .decimalPad : .numberPad)
            .font(.title2.monospaced())
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .accessibilityLabel("回答")
            .accessibilityIdentifier("answerField")
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch session.phase {
        case .answered:
            Button(session.isLast ? "結果を見る" : "次へ") { session.next() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("nextButton")
        default:
            Button("回答する") { session.submit() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!session.canSubmit)
                .accessibilityIdentifier("submitButton")
        }
    }

    private func openCalculator() {
        guard let id = session.current?.id, let subnet = SubnetQuestionGenerator.subnet(fromId: id) else { return }
        calculator = CIDRCalculatorViewModel(address: subnet.address.description, prefix: String(subnet.prefix))
    }
}

extension CIDRCalculatorViewModel: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}

/// S-03b 回答後の表示（S-04 から開いたときも同じ）
struct AnsweredDetail: View {
    let question: Question
    let correct: Bool
    let input: String
    var onVerify: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(correct ? "正解" : "不正解", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(correct ? Color.green : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background((correct ? Color.green : Color.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("verdict")

            VStack(alignment: .leading, spacing: 6) {
                if !correct {
                    answerLine(mark: "✗", label: "あなたの回答", value: input, color: .red)
                }
                answerLine(mark: "✓", label: "正解", value: question.answer, color: .green)
            }

            Text("解説").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    MarkdownText(source: question.explanation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if question.isGenerated, let onVerify {
                        Button(action: onVerify) {
                            HStack {
                                Text("計算機で確かめる")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("verifyButton")
                    }
                }
            }
        }
    }

    private func answerLine(mark: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Text(mark).foregroundStyle(color).bold()
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospaced())
        }
    }
}

/// S-04 学習の結果
struct SessionResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let session: QuizSessionViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("おつかれさまでした").font(.title2.bold()).padding(.top)
            Text("\(session.correctCount) / \(session.outcomes.count) 問 正解")
                .font(.title.bold().monospacedDigit())
                .accessibilityIdentifier("resultScore")

            List {
                if session.wrongOutcomes.isEmpty {
                    Text("全問正解です")
                } else {
                    Section("間違えた問題") {
                        ForEach(session.wrongOutcomes) { outcome in
                            NavigationLink {
                                ScrollView {
                                    AnsweredDetail(question: outcome.question, correct: false, input: outcome.input)
                                        .padding()
                                }
                                .navigationTitle("振り返り")
                                .navigationBarTitleDisplayMode(.inline)
                            } label: {
                                Label {
                                    Text(outcome.question.stem).lineLimit(1)
                                } icon: {
                                    Text("✗").foregroundStyle(.red)
                                }
                            }
                            .accessibilityIdentifier("wrongQuestion")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            if !session.wrongOutcomes.isEmpty {
                Text("間違えた問題は明日また出ます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button("もう1回学習する") {
                    model.historyChanged()
                    model.activeSession = model.makeSession(session.scope)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("againButton")

                Button("ホームに戻る") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(prominent: false))
                    .accessibilityIdentifier("homeButton")
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
