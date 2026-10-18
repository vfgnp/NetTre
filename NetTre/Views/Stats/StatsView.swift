import SwiftUI

/// S-05 成績
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel: StatsViewModel?

    var body: some View {
        ScrollView {
            if let vm = viewModel, vm.hasHistory {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        tile("回答数", "\(vm.summary.total.answered) 問", id: "statsTotal")
                        tile("正答率", StatsViewModel.percentText(vm.summary.total), id: "statsRate")
                        tile("今日の復習", "\(vm.summary.dueToday) 問", id: "statsDue")
                        tile("今日解いた", "\(vm.summary.answeredToday) 問", id: "statsToday")
                    }
                    Text("分野別").font(.headline)
                    ForEach(vm.categories) { category in
                        CategoryRow(category: category)
                    }
                }
                .padding()
            } else {
                Text("問題を解くと、ここに成績が表示されます")
                    .foregroundStyle(.secondary)
                    .padding(.top, 80)
                    .accessibilityIdentifier("statsEmpty")
            }
        }
        .navigationTitle("成績")
        .task(id: model.dataVersion) { refresh() }
        .onAppear { refresh() }
    }

    private func tile(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold().monospacedDigit()).accessibilityIdentifier(id)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func refresh() {
        let vm = StatsViewModel(store: model.store, now: model.environment.now)
        vm.refresh()
        viewModel = vm
    }
}

private struct CategoryRow: View {
    let category: StatsViewModel.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.title)
                Spacer()
                Text(StatsViewModel.percentText(category.stats))
                    .font(category.stats.rate == nil ? .footnote : .headline.monospacedDigit())
                    .foregroundStyle(category.stats.rate == nil ? .secondary : .primary)
            }
            if let rate = category.stats.rate {
                ProgressView(value: rate)
                Text("\(category.stats.answered)問").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
