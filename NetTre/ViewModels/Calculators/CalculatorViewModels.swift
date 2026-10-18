import Foundation
import Observation

/// 計算機の誤りを画面に出す文にまとめたもの
struct CalcFailure: Error, Equatable {
    let message: String
}

extension UInt64 {
    /// 3 けた区切り（地域設定によらず「,」）
    var grouped: String {
        let digits = String(self)
        var out = ""
        for (i, c) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(c)
        }
        return out
    }
}

/// IP アドレスとプレフィックス長の 2 つの欄（S-08〜S-11 で共通）
struct NetworkInput {
    var addressText = ""
    var prefixText = ""

    var isEmpty: Bool { addressText.isEmpty && prefixText.isEmpty }
    var isPartlyEmpty: Bool { addressText.isEmpty || prefixText.isEmpty }

    var addressError: InputError? {
        guard !addressText.isEmpty, case let .failure(e) = IPv4InputParser.address(addressText) else { return nil }
        return e
    }

    var prefixError: InputError? {
        guard !prefixText.isEmpty, case let .failure(e) = IPv4InputParser.prefixOrMask(prefixText) else { return nil }
        return e
    }

    /// 両方そろっていれば Subnet。どちらかが空なら nil
    var subnet: Result<Subnet, InputError>? {
        guard !isPartlyEmpty else { return nil }
        switch (IPv4InputParser.address(addressText), IPv4InputParser.prefixOrMask(prefixText)) {
        case let (.success(a), .success(p)): return .success(Subnet(address: a, prefix: p))
        case let (.failure(e), _), let (_, .failure(e)): return .failure(e)
        }
    }

    mutating func paste(_ s: String) {
        if let parts = IPv4InputParser.splitPasted(s) {
            addressText = parts.address
            prefixText = parts.prefix
        } else {
            addressText = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// −／＋。読めないときは 24 から始める。0〜32 に収める
    mutating func stepPrefix(_ delta: Int) {
        let current = (try? IPv4InputParser.prefixOrMask(prefixText).get()) ?? 24
        prefixText = String(min(max(current + delta, 0), 32))
    }
}

// MARK: - S-08 CIDR 計算

@Observable
final class CIDRCalculatorViewModel {
    var network = NetworkInput()

    init(address: String = "", prefix: String = "") {
        network = NetworkInput(addressText: address, prefixText: prefix)
    }

    var addressText: String {
        get { network.addressText }
        set { network.addressText = newValue }
    }

    var prefixText: String {
        get { network.prefixText }
        set { network.prefixText = newValue }
    }

    /// どちらかが空なら nil（誤りも出さない。§12.13）
    var result: Result<CIDRResult, InputError>? {
        network.subnet.map { $0.map { CIDRCalculator.calculate(address: $0.address, prefix: $0.prefix) } }
    }

    func paste(_ s: String) { network.paste(s) }
    func stepPrefix(_ delta: Int) { network.stepPrefix(delta) }

    /// 「使えるホスト数」の行の文
    static func hostsText(_ s: Subnet) -> String {
        switch s.prefix {
        case 32: "1 台のホスト"
        case 31: "2（ポイントツーポイント用）"
        default: "\(s.usableHosts.grouped)（総数 \(s.totalAddresses.grouped)）"
        }
    }
}

// MARK: - S-09 サブネット分割

@Observable
final class SubnetSplitViewModel {
    enum Kind: String, CaseIterable, Identifiable {
        case count = "分割数"
        case hosts = "ホスト数"
        var id: String { rawValue }
    }

    var network = NetworkInput()
    var kind = Kind.count
    var numberText = ""

    var result: Result<SplitResult, CalcFailure>? {
        guard let parent = network.subnet, !numberText.isEmpty else { return nil }
        switch parent {
        case let .failure(e):
            return .failure(CalcFailure(message: e.message))
        case let .success(parent):
            let digits = AnswerNormalizer.normalize(numberText)
            guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                return .failure(CalcFailure(message: SplitError.invalidNumber.message))
            }
            // 大きすぎる数は Int.max として扱い、上限の誤りにする
            let n = Int(digits) ?? Int.max
            let mode: SplitMode = kind == .count ? .count(n) : .hosts(n)
            return SubnetSplitter.split(parent.normalized, mode: mode).mapError { CalcFailure(message: $0.message) }
        }
    }

    var parent: Subnet? { try? network.subnet?.get().normalized }

    /// 「5 分割 → 8 分割になります」
    var roundedNote: String? {
        guard case let .success(r) = result, case let .count(n) = r.mode, let rounded = r.roundedCount else { return nil }
        return "\(n) 分割 → \(rounded) 分割になります"
    }

    /// 「全 4,194,304 件のうち先頭 256 件」
    var truncationNote: String? {
        guard case let .success(r) = result, r.totalCount > UInt64(r.subnets.count) else { return nil }
        return "全 \(r.totalCount.grouped) 件のうち先頭 \(r.subnets.count) 件"
    }

    var summaryText: String? {
        guard case let .success(r) = result else { return nil }
        return "/\(r.newPrefix) ・ 1 サブネット \(r.hostsPerSubnet.grouped) 台 ・ \(r.totalCount.grouped) 件"
    }
}

// MARK: - S-10 VLSM 設計

@Observable
final class VLSMViewModel {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        var name = ""
        var hostsText = ""
    }

    var network = NetworkInput()
    var rows: [Row] = [Row(), Row()]

    var canAddRow: Bool { rows.count < Constants.vlsmMaxRequirements }

    func addRow() {
        guard canAddRow else { return }
        rows.append(Row())
    }

    func removeRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    var result: Result<VLSMPlan, CalcFailure>? {
        let filled = rows.enumerated().filter { !$0.element.hostsText.isEmpty }
        guard let parent = network.subnet, !filled.isEmpty else { return nil }
        switch parent {
        case let .failure(e):
            return .failure(CalcFailure(message: e.message))
        case let .success(parent):
            var requirements: [VLSMRequirement] = []
            for (i, row) in filled {
                let name = row.name.trimmingCharacters(in: .whitespaces).isEmpty ? "用途\(i + 1)" : row.name
                let digits = AnswerNormalizer.normalize(row.hostsText)
                guard digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                    return .failure(CalcFailure(message: VLSMError.invalidHosts(name: name).message))
                }
                // 大きすぎる数は親に入りきらない数として扱う
                let hosts = min(Int(digits) ?? Int(UInt32.max), Int(UInt32.max))
                requirements.append(VLSMRequirement(id: row.id, name: name, hosts: hosts))
            }
            return VLSMPlanner.plan(parent: parent.normalized, requirements: requirements)
                .mapError { CalcFailure(message: "✗ " + $0.message) }
        }
    }
}

// MARK: - S-11 経路集約

@Observable
final class RouteSummaryViewModel {
    struct Row: Identifiable, Equatable {
        let id = UUID()
        var network = NetworkInput()

        static func == (l: Row, r: Row) -> Bool {
            l.id == r.id && l.network.addressText == r.network.addressText && l.network.prefixText == r.network.prefixText
        }
    }

    var rows: [Row] = [Row(), Row()]

    var canAddRow: Bool { rows.count < Constants.summaryMaxNetworks }

    func addRow() {
        guard canAddRow else { return }
        rows.append(Row())
    }

    func removeRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    var result: Result<SummaryResult, CalcFailure>? {
        var networks: [Subnet] = []
        for row in rows where !row.network.isEmpty {
            switch row.network.subnet {
            case nil: return nil
            case let .failure(e): return .failure(CalcFailure(message: e.message))
            case let .success(s): networks.append(s)
            }
        }
        guard !networks.isEmpty else { return nil }
        return RouteSummarizer.summarize(networks).mapError { CalcFailure(message: $0.message) }
    }

    var hostBitsNote: String? {
        guard case let .success(r) = result, r.normalizedHostBits else { return nil }
        return "ホスト部を 0 にして扱いました"
    }

    var extraText: String? {
        guard case let .success(r) = result else { return nil }
        return r.extraRanges.isEmpty ? "ありません（ちょうど集約できます）" : nil
    }
}

// MARK: - S-12 進数変換

@Observable
final class RadixViewModel {
    var input = ""

    var result: Result<RadixResult, InputError>? {
        input.isEmpty ? nil : RadixConverter.convert(input)
    }

    /// 「16 進として読みました」
    var detectedText: String? {
        guard case let .success(r) = result else { return nil }
        return "\(r.detected.displayName)として読みました"
    }
}

// MARK: - 入力をアプリを閉じるまで残す（§7.1）

@Observable
final class CalculatorStore {
    let cidr = CIDRCalculatorViewModel()
    let split = SubnetSplitViewModel()
    let vlsm = VLSMViewModel()
    let summary = RouteSummaryViewModel()
    let radix = RadixViewModel()
}
