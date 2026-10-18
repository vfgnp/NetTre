// アプリのアイコン（1024×1024、透過なし）を描く。使い方: swift scripts/make_icon.swift <出力パス>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let space = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// 背景：濃い青から青緑への斜めのグラデーション
let gradient = CGGradient(colorsSpace: space, colors: [color(0x0B2E6B), color(0x0E7490), color(0x14B8A6)] as CFArray,
                          locations: [0, 0.6, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

// ネットワーク：中央のノードと、まわりの 5 つのノード。外周どうしもつなぐ
let center = CGPoint(x: 512, y: 500)
let r: CGFloat = 300
let outer = (0..<5).map { i -> CGPoint in
    let angle = CGFloat.pi / 2 + CGFloat(i) * 2 * .pi / 5
    return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
}
ctx.setLineCap(.round)
ctx.setStrokeColor(color(0xFFFFFF, 0.35))
ctx.setLineWidth(18)
for i in 0..<5 {
    ctx.move(to: outer[i]); ctx.addLine(to: outer[(i + 1) % 5])
}
ctx.strokePath()
ctx.setStrokeColor(color(0xFFFFFF, 0.95))
ctx.setLineWidth(30)
for p in outer {
    ctx.move(to: center); ctx.addLine(to: p)
}
ctx.strokePath()

func node(_ p: CGPoint, _ radius: CGFloat, fill: CGColor) {
    ctx.setFillColor(fill)
    ctx.fillEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
}
for p in outer {
    node(p, 70, fill: color(0xFFFFFF))
    node(p, 40, fill: color(0x0E7490))
}
node(center, 120, fill: color(0xFFFFFF))
node(center, 78, fill: color(0xF59E0B))

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
