import Foundation

enum Radix: Equatable {
    case decimal, binary, hex

    var displayName: String {
        switch self {
        case .decimal: "10 進"
        case .binary: "2 進"
        case .hex: "16 進"
        }
    }
}

struct RadixResult: Equatable {
    let detected: Radix
    let value: IPv4
}

/// 進数変換（FR-21、D9）
enum RadixConverter {
    static func convert(_ input: String) -> Result<RadixResult, InputError> {
        let t = AnswerNormalizer.normalize(input)
        guard !t.isEmpty else { return .failure(.empty) }

        // 1. 0x で始まる・a〜f を含む → 16 進
        if t.hasPrefix("0x") || t.contains(where: { "abcdef".contains($0) }) {
            let body = t.hasPrefix("0x") ? String(t.dropFirst(2)) : t
            guard let value = parseHex(body) else { return .failure(.invalidRadix) }
            return .success(RadixResult(detected: .hex, value: IPv4(value)))
        }
        // 2. 0 と 1 だけで 8 けた × 4、または 32 けた → 2 進
        let groups = t.split(separator: ".", omittingEmptySubsequences: false)
        let isBits: (Substring) -> Bool = { $0.allSatisfy { $0 == "0" || $0 == "1" } }
        if groups.count == 4, groups.allSatisfy({ $0.count == 8 && isBits($0) }) {
            return .success(RadixResult(detected: .binary, value: IPv4(UInt32(groups.joined(), radix: 2) ?? 0)))
        }
        if groups.count == 1, t.count == 32, isBits(Substring(t)) {
            return .success(RadixResult(detected: .binary, value: IPv4(UInt32(t, radix: 2) ?? 0)))
        }
        // 3. それ以外 → 10 進
        return IPv4InputParser.address(t).map { RadixResult(detected: .decimal, value: $0) }
    }

    private static func parseHex(_ body: String) -> UInt32? {
        let isHex: (Substring) -> Bool = { !$0.isEmpty && $0.allSatisfy(\.isHexDigit) }
        if body.contains(".") {
            let parts = body.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 4, parts.allSatisfy({ $0.count <= 2 && isHex($0) }) else { return nil }
            return parts.reduce(UInt32(0)) { $0 << 8 | (UInt32($1, radix: 16) ?? 0) }
        }
        guard body.count == 8, isHex(Substring(body)) else { return nil }
        return UInt32(body, radix: 16)
    }
}
