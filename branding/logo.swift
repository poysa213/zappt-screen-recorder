import AppKit
import CoreGraphics

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a).cgColor
}

// Brand palette
let gradTL = color(0x7A, 0x7B, 0xF0)   // light indigo/violet
let gradBR = color(0x49, 0x3F, 0xD4)   // deep indigo
let indigo = color(0x5B, 0x5B, 0xD6)
let dark   = color(0x1A, 0x1A, 0x1E)
let white  = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let black  = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext)
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, _ name: String) {
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try! data.write(to: url)
    print("wrote \(url.path)")
}

// Apple-style squircle (superellipse) path.
func squircle(_ rect: CGRect, n: CGFloat = 5) -> CGPath {
    let p = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 1024
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

/// The Zappt mark: a bold lightning bolt ("zap"). `height` is the bolt's height;
/// it's drawn centered on `c`, filled and round-joined for a friendly, crisp look.
func drawBolt(_ cg: CGContext, center c: CGPoint, height H: CGFloat, color: CGColor) {
    let W = H * 0.52
    // Classic lightning-bolt outline, normalized (x right, y DOWN).
    let pts: [(CGFloat, CGFloat)] = [
        (0.06, 0.00), (0.00, 0.54), (0.34, 0.54),
        (0.24, 1.00), (1.00, 0.40), (0.60, 0.40), (0.94, 0.00)
    ]
    let originX = c.x - W / 2
    let topY = c.y + H / 2      // y-up context: top edge is the higher y
    let path = CGMutablePath()
    for (i, p) in pts.enumerated() {
        let x = originX + p.0 * W
        let y = topY - p.1 * H
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()

    cg.saveGState()
    cg.setFillColor(color)
    cg.setStrokeColor(color)
    cg.setLineWidth(H * 0.08)
    cg.setLineJoin(.round)
    cg.setLineCap(.round)
    cg.addPath(path); cg.fillPath()
    cg.addPath(path); cg.strokePath()
    cg.restoreGState()
}

// MARK: - App icon (1024, full-bleed squircle)

let icon = render(width: 1024, height: 1024) { cg in
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let sq = squircle(body)

    cg.saveGState()
    cg.addPath(sq); cg.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [gradTL, gradBR] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(grad,
                          start: CGPoint(x: body.minX, y: body.maxY),
                          end: CGPoint(x: body.maxX, y: body.minY), options: [])
    let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14),
                                    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0)] as CFArray,
                           locations: [0, 1])!
    cg.drawLinearGradient(sheen,
                          start: CGPoint(x: body.midX, y: body.maxY),
                          end: CGPoint(x: body.midX, y: body.midY), options: [])
    cg.restoreGState()

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30,
                 color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.20))
    drawBolt(cg, center: CGPoint(x: 512, y: 512), height: 520, color: white)
    cg.restoreGState()
}
write(icon, "icon-1024.png")

// MARK: - Standalone marks (transparent)

func markImage(_ c: CGColor) -> NSBitmapImageRep {
    render(width: 512, height: 512) { cg in
        drawBolt(cg, center: CGPoint(x: 256, y: 256), height: 360, color: c)
    }
}
write(markImage(indigo), "mark.png")
write(markImage(white), "mark-white.png")
write(markImage(black), "mark-black.png")

// MARK: - Wordmark lockups

func wordmark(textColor: CGColor, mark: CGColor) -> NSBitmapImageRep {
    render(width: 1480, height: 460) { cg in
        drawBolt(cg, center: CGPoint(x: 170, y: 230), height: 300, color: mark)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 250, weight: .bold),
            .foregroundColor: NSColor(cgColor: textColor)!,
            .kern: -4
        ]
        let s = NSAttributedString(string: "Zappt", attributes: attrs)
        let size = s.size()
        s.draw(at: NSPoint(x: 320, y: 230 - size.height / 2))
    }
}
write(wordmark(textColor: dark, mark: indigo), "wordmark-light.png")
write(wordmark(textColor: white, mark: white), "wordmark-dark.png")
