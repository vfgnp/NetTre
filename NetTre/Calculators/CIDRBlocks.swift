import Foundation

/// 範囲 [start, end]（両端を含む）を、境界のそろった最大の CIDR のまとまりに分ける（詳細設計 §6.4）
enum CIDRBlocks {
    static func blocks(from start: UInt64, to end: UInt64, limit: Int) -> (blocks: [Subnet], truncated: Bool) {
        var blocks: [Subnet] = []
        var cursor = start
        let last = min(end, UInt64(UInt32.max))
        while cursor <= last {
            if blocks.count >= limit { return (blocks, true) }
            // cursor の境界に合う最大の大きさ（cursor = 0 なら 2^32）
            let alignBits = cursor == 0 ? 32 : min(cursor.trailingZeroBitCount, 32)
            var size = UInt64(1) << UInt64(alignBits)
            while cursor + size - 1 > last { size >>= 1 }
            let prefix = 32 - size.trailingZeroBitCount
            blocks.append(Subnet(address: IPv4(UInt32(cursor)), prefix: prefix))
            cursor += size
        }
        return (blocks, false)
    }
}
