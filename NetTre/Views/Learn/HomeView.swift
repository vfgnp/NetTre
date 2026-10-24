import SwiftUI

/// S-01 ホーム
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: HomeViewModel?

    var body: some View {
        VStack(spacing: 16) {
            summaryCard
            Spacer()
            NavigationLink {
                DomainListView()
            } label: {
                HStack {
                    Text("分野を選ぶ")
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(PrimaryButtonStyle(prominent: false))
            .accessibilityIdentifier("chooseDomainButton")

            Button("学習を始める") { model.startSession(.mixed) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startButton")
        }
        .padding()
        .navigationTitle("NetTre")
        .task(id: model.dataVersion) { refresh() }
        .onAppear { refresh() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日の復習").font(.headline)
            if let message = viewModel?.dueMessage {
                Text(message)
                    .font(.title3.bold())
                    .accessibilityIdentifier("dueMessage")
            } else {
                Text("\(viewModel?.dueToday ?? 0) 問")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("dueCount")
            }
            HStack {
                Text("今日解いた問題")
                Spacer()
                Text("\(viewModel?.answeredToday ?? 0) 問")
                    .font(.headline)
                    .accessibilityIdentifier("answeredToday")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func refresh() {
        let vm = HomeViewModel(store: model.store, now: model.environment.now)
        vm.refresh()
        viewModel = vm
    }
}

/// S-02 分野選択
struct DomainListView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: DomainListViewModel?
    @AppStorage(DefaultsKey.subnetDrillDifficulty) private var difficultyRaw = Difficulty.standard.rawValue

    var body: some View {
        List {
            Section("サブネット計算ドリル") {
                Picker("難易度", selection: $difficultyRaw) {
                    ForEach(Difficulty.allCases) { level in
                        Text(level.displayName).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("difficultyPicker")

                Button {
                    model.startSession(.subnetDrill(Difficulty(rawValue: difficultyRaw) ?? .standard))
                } label: {
                    HStack {
                        Text("始める")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .frame(minHeight: Constants.minTapHeight)
                }
                .accessibilityIdentifier("startDrillButton")
            }

            Section("分野") {
                ForEach(viewModel?.rows ?? []) { row in
                    Button {
                        model.startSession(.domain(row.domain))
                    } label: {
                        DomainRowView(row: row)
                    }
                    .disabled(!row.isAvailable)
                    .accessibilityIdentifier("domain-\(row.domain.rawValue)")
                }
            }
        }
        .navigationTitle("分野を選ぶ")
        .task(id: model.dataVersion) { refresh() }
    }

    private func refresh() {
        let vm = DomainListViewModel(store: model.store, repository: model.repository, now: model.environment.now)
        vm.refresh()
        viewModel = vm
    }
}

private struct DomainRowView: View {
    let row: DomainListViewModel.Row

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.domain.displayName)
                    .foregroundStyle(row.isAvailable ? Color.primary : Color.secondary)
                if row.isAvailable {
                    Text("\(row.questionCount)問 ・ 復習 \(row.dueCount)問")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if row.isAvailable {
                Text(row.rateText).font(.headline.monospacedDigit())
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            } else {
                Text("準備中").foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: Constants.minTapHeight)
    }
}
