import Foundation

struct VLSMRequirement: Identifiable, Equatable {
    let id: UUID
    var name: String
    var hosts: Int

    init(id: UUID = UUID(), name: String, hosts: Int) {
        self.id = id
        self.name = name
        self.hosts = hosts
    }
}

struct VLSMAllocation: Equatable {
    let requirement: VLSMRequirement
    let subnet: Subnet
}

struct VLSMPlan: Equatable {
    let allocations: [VLSMAllocation]
    let freeBlocks: [Subnet]
}

enum VLSMError: Error, Equatable {
    case shortage(UInt64)
    case invalidHosts(name: String)
    case tooMany

    var message: String {
        switch self {
        case let .shortage(n): "親ネットワークに \(n) アドレス足りません"
        case let .invalidHosts(name): "「\(name)」の必要ホスト数は 1 以上にしてください"
        case .tooMany: "用途は \(Constants.vlsmMaxRequirements) 件までです"
        }
    }
}

/// VLSM 設計（FR-19、詳細設計 §6.6）
enum VLSMPlanner {
    /// h + 2 以上の最小の 2 の累乗
    static func blockSize(forHosts h: Int) -> UInt64 {
        let need = UInt64(max(h, 0)) + 2
        var size: UInt64 = 1
        while size < need { size <<= 1 }
        return size
    }

    static func plan(parent: Subnet, requirements: [VLSMRequirement]) -> Result<VLSMPlan, VLSMError> {
        guard requirements.count <= Constants.vlsmMaxRequirements else { return .failure(.tooMany) }
        if let bad = requirements.first(where: { $0.hosts < 1 }) {
            return .failure(.invalidHosts(name: bad.name))
        }
        let total = parent.totalAddresses
        let needed = requirements.reduce(UInt64(0)) { $0 + blockSize(forHosts: $1.hosts) }
        guard needed <= total else { return .failure(.shortage(needed - total)) }

        // 必要ホスト数の多い順。同じなら入力順（安定）
        let ordered = requirements.enumerated()
            .sorted { $0.element.hosts != $1.element.hosts ? $0.element.hosts > $1.element.hosts : $0.offset < $1.offset }
            .map(\.element)
        var cursor = UInt64(parent.network.value)
        var allocations: [VLSMAllocation] = []
        for requirement in ordered {
            let size = blockSize(forHosts: requirement.hosts)
            let prefix = 32 - size.trailingZeroBitCount
            allocations.append(VLSMAllocation(requirement: requirement,
                                              subnet: Subnet(address: IPv4(UInt32(cursor)), prefix: prefix)))
            cursor += size
        }
        let end = UInt64(parent.broadcast.value)
        let free = cursor <= end
            ? CIDRBlocks.blocks(from: cursor, to: end, limit: Constants.extraRangesDisplayLimit).blocks
            : []
        return .success(VLSMPlan(allocations: allocations, freeBlocks: free))
    }
}
