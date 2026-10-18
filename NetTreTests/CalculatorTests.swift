import Foundation
import Testing
@testable import NetTre

private let ip = TestSupport.ip
private let net = TestSupport.subnet

// 05 §7.1 IPv4・Subnet
struct SubnetTests {
    @Test("UT-SN-01")
    func slash26() {
        let s = Subnet(address: ip("192.168.10.77"), prefix: 26)
        #expect(s.network.description == "192.168.10.64")
        #expect(s.broadcast.description == "192.168.10.127")
        #expect(s.mask.description == "255.255.255.192")
        #expect(s.wildcard.description == "0.0.0.63")
        #expect(s.firstHost.description == "192.168.10.65")
        #expect(s.lastHost.description == "192.168.10.126")
        #expect(s.usableHosts == 62)
        #expect(s.totalAddresses == 64)
    }

    @Test("UT-SN-02")
    func slash20() {
        let s = Subnet(address: ip("172.20.133.5"), prefix: 20)
        #expect(s.network.description == "172.20.128.0")
        #expect(s.broadcast.description == "172.20.143.255")
    }

    @Test("UT-SN-03")
    func slash0() {
        let s = Subnet(address: ip("10.0.0.1"), prefix: 0)
        #expect(s.network.description == "0.0.0.0")
        #expect(s.broadcast.description == "255.255.255.255")
        #expect(s.totalAddresses == 4_294_967_296)
        #expect(s.usableHosts == 4_294_967_294)
    }

    @Test("UT-SN-04〜06")
    func smallPrefixes() {
        let s30 = Subnet(address: ip("10.0.0.1"), prefix: 30)
        #expect(s30.usableHosts == 2)
        #expect("\(s30.firstHost)〜\(s30.lastHost)" == "10.0.0.1〜10.0.0.2")
        let s31 = Subnet(address: ip("10.0.0.1"), prefix: 31)
        #expect(s31.usableHosts == 2)
        #expect("\(s31.firstHost)〜\(s31.lastHost)" == "10.0.0.0〜10.0.0.1")
        let s32 = Subnet(address: ip("10.0.0.1"), prefix: 32)
        #expect(s32.usableHosts == 1)
        #expect("\(s32.firstHost)〜\(s32.lastHost)" == "10.0.0.1〜10.0.0.1")
    }

    @Test("UT-SN-07")
    func allOnes() {
        #expect(Subnet(address: ip("255.255.255.255"), prefix: 24).broadcast.description == "255.255.255.255")
        #expect(Subnet(address: ip("255.255.255.255"), prefix: 32).broadcast.description == "255.255.255.255")
    }

    struct CIDRFixture: Decodable {
        let address: String, prefix: Int, network: String, broadcast: String, mask: String, wildcard: String
        let total: UInt64, usable: UInt64, first: String, last: String
    }

    @Test("UT-SN-08 照合用データ")
    func fixtures() throws {
        let cases = try TestSupport.fixture("cidr_fixtures", as: [CIDRFixture].self)
        #expect(cases.count >= 10_000)
        var mismatches = 0
        for c in cases {
            let s = Subnet(address: ip(c.address), prefix: c.prefix)
            let ok = s.network.description == c.network && s.broadcast.description == c.broadcast
                && s.mask.description == c.mask && s.wildcard.description == c.wildcard
                && s.totalAddresses == c.total && s.usableHosts == c.usable
                && s.firstHost.description == c.first && s.lastHost.description == c.last
            if !ok { mismatches += 1 }
        }
        #expect(mismatches == 0)
    }

    @Test("UT-SN-09")
    func notations() {
        #expect(ip("192.168.10.77").binaryString == "11000000.10101000.00001010.01001101")
        #expect(ip("192.168.10.77").hexString == "C0.A8.0A.4D")
    }
}

// 05 §7.2 IPv4InputParser
struct IPv4InputParserTests {
    @Test("UT-IP-01", arguments: ["192.168.10.77", "１９２．１６８．１０．７７", "192,168,10,77"])
    func address(input: String) {
        #expect(IPv4InputParser.address(input) == .success(ip("192.168.10.77")))
    }

    @Test("UT-IP-02・15")
    func leadingZeros() {
        #expect(IPv4InputParser.address("010.001.000.009") == .success(IPv4(10, 1, 0, 9)))
        #expect(IPv4InputParser.address("0010.1.2.3") == .success(IPv4(10, 1, 2, 3)))
    }

    @Test("UT-IP-03〜06・13")
    func addressErrors() {
        #expect(IPv4InputParser.address("") == .failure(.empty))
        #expect(IPv4InputParser.address("192.168.10") == .failure(.octetCount(3)))
        #expect(IPv4InputParser.address("1.2.3.4.5") == .failure(.octetCount(5)))
        #expect(IPv4InputParser.address("192.168.256.1") == .failure(.octetRange(index: 3, value: 256)))
        #expect(InputError.octetRange(index: 3, value: 256).message == "第3オクテットが 256 です（0〜255）")
        #expect(IPv4InputParser.address("192.168.a.1") == .failure(.notNumber(index: 3)))
        #expect(IPv4InputParser.address("192..10.77") == .failure(.notNumber(index: 2)))
        #expect(IPv4InputParser.address("192.168.10.") == .failure(.notNumber(index: 4)))
        #expect(IPv4InputParser.address("1.2.3.99999999999999999999") == .failure(.octetRange(index: 4, value: Int.max)))
        #expect(InputError.octetRange(index: 4, value: Int.max).message == "第4オクテットが大きすぎます（0〜255）")
        #expect(IPv4InputParser.address("1.2.3.0256") == .failure(.octetRange(index: 4, value: 256)))
    }

    @Test("UT-IP-07〜10")
    func prefixOrMask() {
        #expect(IPv4InputParser.prefixOrMask("26") == .success(26))
        #expect(IPv4InputParser.prefixOrMask("0") == .success(0))
        #expect(IPv4InputParser.prefixOrMask("32") == .success(32))
        #expect(IPv4InputParser.prefixOrMask("33") == .failure(.prefixRange(33)))
        #expect(IPv4InputParser.prefixOrMask("-1") == .failure(.invalidPrefix))
        #expect(IPv4InputParser.prefixOrMask("abc") == .failure(.invalidPrefix))
        #expect(IPv4InputParser.prefixOrMask("255.255.255.192") == .success(26))
        #expect(IPv4InputParser.prefixOrMask("0.0.0.0") == .success(0))
        #expect(IPv4InputParser.prefixOrMask("255.255.255.255") == .success(32))
        #expect(IPv4InputParser.prefixOrMask("255.0.255.0") == .failure(.maskNotContiguous))
        #expect(IPv4InputParser.prefixOrMask("255.255.255.193") == .failure(.maskNotContiguous))
    }

    @Test("UT-IP-11・12・14")
    func splitPasted() {
        for s in ["192.168.10.77/26", " 192.168.10.77 / 26 "] {
            let r = IPv4InputParser.splitPasted(s)
            #expect(r?.address == "192.168.10.77" && r?.prefix == "26")
        }
        let m = IPv4InputParser.splitPasted("192.168.10.77 255.255.255.192")
        #expect(m?.address == "192.168.10.77" && m?.prefix == "255.255.255.192")
        #expect(IPv4InputParser.splitPasted("192.168.10.77") == nil)
        #expect(IPv4InputParser.splitPasted(" 192.168.10.77 ") == nil)

        let vm = CIDRCalculatorViewModel(prefix: "24")
        vm.paste(" 192.168.10.77 ")
        #expect(vm.addressText == "192.168.10.77")
        #expect(vm.prefixText == "24")
    }
}

// 05 §7.3 CIDRCalculator・AddressKind
struct AddressKindTests {
    @Test("UT-CC-01〜08・10", arguments: [
        ("127.0.0.1", AddressKind.loopback), ("126.255.255.255", .global),
        ("10.0.0.0", .private), ("172.16.0.0", .private), ("172.31.255.255", .private), ("192.168.0.1", .private),
        ("172.15.255.255", .global), ("172.32.0.0", .global),
        ("169.254.1.1", .linkLocal), ("169.253.255.255", .global),
        ("100.64.0.0", .sharedAddress), ("100.127.255.255", .sharedAddress),
        ("100.63.255.255", .global), ("100.128.0.0", .global),
        ("224.0.0.1", .multicast), ("239.255.255.255", .multicast), ("223.255.255.255", .global),
        ("240.0.0.1", .reserved), ("0.1.2.3", .reserved),
        ("8.8.8.8", .global),
        ("9.255.255.255", .global), ("11.0.0.0", .global), ("192.167.255.255", .global), ("192.169.0.0", .global),
    ])
    func kind(address: String, expected: AddressKind) {
        #expect(AddressKind(ip(address)) == expected)
    }

    @Test("UT-CC-09")
    func calculate() {
        let r = CIDRCalculator.calculate(address: ip("192.168.10.77"), prefix: 26)
        #expect(r.subnet == Subnet(address: ip("192.168.10.77"), prefix: 26))
        #expect(r.kind == .private)
        #expect(r.steps == CalculationSteps.cidr(r.subnet))
    }
}

// 05 §7.4 CIDRBlocks
struct CIDRBlocksTests {
    func blocks(_ a: String, _ b: String, limit: Int = 10_000) -> ([String], Bool) {
        let r = CIDRBlocks.blocks(from: UInt64(ip(a).value), to: UInt64(ip(b).value), limit: limit)
        return (r.blocks.map(\.cidrString), r.truncated)
    }

    @Test("UT-CB-01〜04")
    func cases() {
        let all = ["192.168.10.100/30", "192.168.10.104/29", "192.168.10.112/28", "192.168.10.128/25"]
        #expect(blocks("192.168.10.100", "192.168.10.255") == (all, false))
        #expect(blocks("0.0.0.0", "255.255.255.255") == (["0.0.0.0/0"], false))
        #expect(blocks("10.0.0.5", "10.0.0.5") == (["10.0.0.5/32"], false))
        #expect(blocks("192.168.10.100", "192.168.10.255", limit: 2) == (Array(all.prefix(2)), true))
        #expect(blocks("192.168.10.100", "192.168.10.255", limit: 4) == (all, false))
    }

    struct BlockFixture: Decodable { let start: UInt64, end: UInt64, blocks: [String] }

    @Test("UT-CB-05 照合用データ")
    func fixtures() throws {
        let cases = try TestSupport.fixture("blocks_fixtures", as: [BlockFixture].self)
        #expect(!cases.isEmpty)
        var mismatches = 0
        for c in cases where CIDRBlocks.blocks(from: c.start, to: c.end, limit: 100_000).blocks.map(\.cidrString) != c.blocks {
            mismatches += 1
        }
        #expect(mismatches == 0)
    }
}

// 05 §7.5 SubnetSplitter
struct SubnetSplitterTests {
    let parent = net("192.168.10.0/24")

    func split(_ p: Subnet, _ mode: SplitMode) -> SplitResult? { try? SubnetSplitter.split(p, mode: mode).get() }

    @Test("UT-SP-01〜04")
    func byCount() throws {
        let r4 = try #require(split(parent, .count(4)))
        #expect(r4.newPrefix == 26 && r4.hostsPerSubnet == 62)
        #expect(r4.subnets.map { $0.network.description } == ["192.168.10.0", "192.168.10.64", "192.168.10.128", "192.168.10.192"])
        let r5 = try #require(split(parent, .count(5)))
        #expect(r5.newPrefix == 27 && r5.roundedCount == 8 && r5.subnets.count == 8)
        let r1 = try #require(split(parent, .count(1)))
        #expect(r1.newPrefix == 24 && r1.subnets.count == 1 && r1.roundedCount == nil)
        let r128 = try #require(split(parent, .count(128)))
        #expect(r128.newPrefix == 31 && r128.hostsPerSubnet == 2)
        let r256 = try #require(split(parent, .count(256)))
        #expect(r256.newPrefix == 32 && r256.hostsPerSubnet == 1)
    }

    @Test("UT-SP-05・08・11")
    func errors() {
        #expect(SubnetSplitter.split(net("10.0.0.0/30"), mode: .count(8)) == .failure(.tooSmall))
        #expect(SubnetSplitter.split(parent, mode: .hosts(300)) == .failure(.exceedsParent))
        #expect(SubnetSplitter.split(parent, mode: .hosts(4_294_967_295)) == .failure(.exceedsParent))
        #expect(SubnetSplitter.split(parent, mode: .count(0)) == .failure(.invalidNumber))
        #expect(SubnetSplitter.split(parent, mode: .hosts(0)) == .failure(.invalidNumber))
    }

    @Test("UT-SP-06・07")
    func byHosts() {
        #expect(split(parent, .hosts(62))?.newPrefix == 26)
        #expect(split(parent, .hosts(63))?.newPrefix == 25)
        #expect(split(parent, .hosts(1))?.newPrefix == 30)
    }

    @Test("UT-SP-09・10")
    func largeAndTop() throws {
        let r = try #require(split(net("10.0.0.0/8"), .hosts(2)))
        #expect(r.totalCount == 4_194_304)
        #expect(r.subnets.count == 256)
        let top = try #require(split(net("255.255.255.0/24"), .count(4)))
        #expect(top.subnets.last?.cidrString == "255.255.255.192/26")
    }
}

// 05 §7.6 VLSMPlanner
struct VLSMPlannerTests {
    func req(_ name: String, _ hosts: Int) -> VLSMRequirement { VLSMRequirement(name: name, hosts: hosts) }
    func plan(_ parent: String, _ reqs: [VLSMRequirement]) -> Result<VLSMPlan, VLSMError> {
        VLSMPlanner.plan(parent: net(parent), requirements: reqs)
    }

    @Test("UT-VL-01・02")
    func basic() throws {
        let expected = [("営業部", "192.168.10.0/26"), ("開発部", "192.168.10.64/27"), ("拠点間リンク", "192.168.10.96/30")]
        let free = ["192.168.10.100/30", "192.168.10.104/29", "192.168.10.112/28", "192.168.10.128/25"]
        for reqs in [[req("営業部", 50), req("開発部", 25), req("拠点間リンク", 2)],
                     [req("拠点間リンク", 2), req("営業部", 50), req("開発部", 25)]] {
            let p = try plan("192.168.10.0/24", reqs).get()
            #expect(p.allocations.map(\.requirement.name) == expected.map(\.0))
            #expect(p.allocations.map(\.subnet.cidrString) == expected.map(\.1))
            #expect(p.freeBlocks.map(\.cidrString) == free)
        }
    }

    @Test("UT-VL-03")
    func stable() throws {
        let p = try plan("192.168.10.0/24", [req("A", 30), req("B", 30)]).get()
        #expect(p.allocations.map(\.requirement.name) == ["A", "B"])
    }

    @Test("UT-VL-04〜06")
    func errors() {
        #expect(plan("192.168.10.0/26", [req("A", 50), req("B", 25)]) == .failure(.shortage(32)))
        #expect(plan("192.168.10.0/24", [req("営業部", 50), req("開発部", 0)]) == .failure(.invalidHosts(name: "開発部")))
        let fifty = (1...50).map { req("R\($0)", 2) }
        let ok = (try? plan("192.168.10.0/24", fifty).get()) != nil
        #expect(ok)
        #expect(plan("192.168.10.0/24", fifty + [req("R51", 2)]) == .failure(.tooMany))
    }

    @Test("UT-VL-07〜09")
    func boundaries() throws {
        #expect(try plan("192.168.10.0/24", [req("A", 126), req("B", 126)]).get().freeBlocks.isEmpty)
        let top = try plan("255.255.255.0/24", [req("A", 100)]).get()
        #expect(top.allocations.map(\.subnet.cidrString) == ["255.255.255.0/25"])
        #expect(top.freeBlocks.map(\.cidrString) == ["255.255.255.128/25"])
        let full = try plan("255.255.255.0/24", [req("A", 126), req("B", 126)]).get()
        #expect(full.allocations.map(\.subnet.cidrString) == ["255.255.255.0/25", "255.255.255.128/25"])
        #expect(full.freeBlocks.isEmpty)
    }
}

// 05 §7.7 RouteSummarizer
struct RouteSummarizerTests {
    func summarize(_ s: [String]) -> Result<SummaryResult, SummaryError> { RouteSummarizer.summarize(s.map(net)) }

    @Test("UT-RT-01〜04")
    func cases() throws {
        let r1 = try summarize(["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"]).get()
        #expect(r1.route.cidrString == "192.168.0.0/22")
        #expect(r1.extraRanges.map(\.cidrString) == ["192.168.3.0/24"])
        let r2 = try summarize((0...3).map { "192.168.\($0).0/24" }).get()
        #expect(r2.route.cidrString == "192.168.0.0/22" && r2.extraRanges.isEmpty)
        let r3 = try summarize(["10.0.0.0/24"]).get()
        #expect(r3.route.cidrString == "10.0.0.0/24" && r3.extraRanges.isEmpty)
        let r3b = try summarize(["255.255.255.255/32"]).get()
        #expect(r3b.route.cidrString == "255.255.255.255/32" && r3b.extraRanges.isEmpty)
        let r4 = try summarize(["192.168.0.0/24", "192.168.1.77/24"]).get()
        #expect(r4.normalizedHostBits)
        #expect(r4.route.cidrString == "192.168.0.0/23")
    }

    @Test("UT-RT-05")
    func wide() throws {
        let r = try summarize(["10.0.0.0/8", "192.168.0.0/16"]).get()
        #expect(r.route.cidrString == "0.0.0.0/0")
        #expect(r.extraRanges.count == 22)
        #expect(r.extraRanges.first?.cidrString == "0.0.0.0/5")
        #expect(r.extraRanges.last?.cidrString == "224.0.0.0/3")
    }

    @Test("UT-RT-06")
    func limits() {
        #expect(summarize([]) == .failure(.empty))
        let thirtyTwo = (0..<32).map { "10.0.\($0).0/24" }
        let ok = (try? summarize(thirtyTwo).get()) != nil
        #expect(ok)
        #expect(summarize(thirtyTwo + ["10.0.32.0/24"]) == .failure(.tooMany))
    }

    @Test("UT-RT-08")
    func truncated() throws {
        let r = try summarize((1...32).map { "\($0).0.0.1/32" }).get()
        #expect(r.route.cidrString == "0.0.0.0/2")
        #expect(r.extraRanges.count == 256)
        #expect(r.extraTruncated)
    }

    struct SummaryFixture: Decodable { let networks: [String], route: String, extra: [String], extraTruncated: Bool }

    @Test("UT-RT-07 照合用データ")
    func fixtures() throws {
        let cases = try TestSupport.fixture("summary_fixtures", as: [SummaryFixture].self)
        #expect(!cases.isEmpty)
        var mismatches = 0
        for c in cases {
            guard let r = try? summarize(c.networks).get() else { mismatches += 1; continue }
            if r.route.cidrString != c.route || r.extraRanges.map(\.cidrString) != c.extra
                || r.extraTruncated != c.extraTruncated {
                mismatches += 1
            }
        }
        #expect(mismatches == 0)
    }
}

// 05 §7.8 RadixConverter
struct RadixConverterTests {
    @Test("UT-RX-01〜05")
    func detect() throws {
        let dec = try RadixConverter.convert("255.255.255.192").get()
        #expect(dec.detected == .decimal)
        #expect(dec.value.binaryString == "11111111.11111111.11111111.11000000")
        #expect(dec.value.hexString == "FF.FF.FF.C0")
        let bin = try RadixConverter.convert("11111111.11111111.11111111.11000000").get()
        #expect(bin.detected == .binary && bin.value == ip("255.255.255.192"))
        let bin32 = try RadixConverter.convert("11111111111111111111111111000000").get()
        #expect(bin32.detected == .binary && bin32.value == ip("255.255.255.192"))
        for s in ["0xFFFFFFC0", "ff.ff.ff.c0", "FF.FF.FF.C0"] {
            let hex = try RadixConverter.convert(s).get()
            #expect(hex.detected == .hex && hex.value == ip("255.255.255.192"))
        }
        let ten = try RadixConverter.convert("10.10.10.10").get()
        #expect(ten.detected == .decimal && ten.value == ip("10.10.10.10"))
    }

    @Test("UT-RX-06")
    func errors() {
        #expect(RadixConverter.convert("0x1G") == .failure(.invalidRadix))
        #expect(RadixConverter.convert("1.2.3") == .failure(.octetCount(3)))
    }
}

// 05 §7.9 CalculationSteps
struct CalculationStepsTests {
    @Test("UT-CS-01〜04")
    func cidr() {
        #expect(CalculationSteps.cidr(net("192.168.10.77/26")) == [
            "区切りは第 4 オクテット。ブロックサイズは 64",
            "77 は 64 の 1 倍〜2 倍の間なので、ネットワークは .64",
        ])
        #expect(CalculationSteps.cidr(net("172.20.133.5/20")) == [
            "区切りは第 3 オクテット。ブロックサイズは 16",
            "133 は 16 の 8 倍〜9 倍の間なので、ネットワークは .128",
        ])
        #expect(CalculationSteps.cidr(net("10.1.2.3/16")) == ["オクテットの境目なので、第 3 オクテットから後ろを 0 にする"])
        #expect(CalculationSteps.cidr(net("10.1.2.3/32")) == ["ホスト部がないので、アドレスそのものがネットワーク"])
        #expect(CalculationSteps.cidr(net("10.1.2.3/0")) == ["すべてのビットがホスト部なので、ネットワークは 0.0.0.0"])
    }

    @Test("UT-CS-05")
    func others() throws {
        let parent = net("192.168.10.0/24")
        let split = try SubnetSplitter.split(parent, mode: .count(5)).get()
        let s = CalculationSteps.split(split, parent: parent)
        #expect(check((1...3).contains(s.count)))
        #expect(check(s.joined().contains("/27") && s.joined().contains("8 分割")))

        let plan = try VLSMPlanner.plan(parent: parent, requirements: [
            VLSMRequirement(name: "営業部", hosts: 50), VLSMRequirement(name: "開発部", hosts: 25),
            VLSMRequirement(name: "拠点間リンク", hosts: 2),
        ]).get()
        let v = CalculationSteps.vlsm(plan)
        #expect(check((1...3).contains(v.count)))
        #expect(check(v.joined().contains("営業部 64") && v.joined().contains("開発部 32") && v.joined().contains("拠点間リンク 4")))

        let summary = try RouteSummarizer.summarize(["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"].map(net)).get()
        let r = CalculationSteps.summary(summary)
        #expect(check((1...3).contains(r.count)))
        #expect(check(r.joined().contains("/22")))
    }
}
