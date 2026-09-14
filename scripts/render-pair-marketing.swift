import AppKit
import ImageIO
import UniformTypeIdentifiers

// Pass "ipad" after the staging directory for native iPad composition.
let dir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let device = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "iphone"
precondition(["iphone", "ipad"].contains(device))
let isPad = device == "ipad"
let width = isPad ? 2064 : 1320
let height = isPad ? 2752 : 2868
let fontSize: CGFloat = isPad ? 164 : 120
let titleTop: CGFloat = isPad ? 160 : 210
let lineHeight: CGFloat = isPad ? 180 : 136
let screenWidth: CGFloat = isPad ? 1240 : 760
let frameWidth: CGFloat = isPad ? 16 : 9
let radius: CGFloat = isPad ? 48 : 58
// Outer margins match each device's single-screen cards (iPhone 96 px; iPad 150 px).
let frames: [(String, CGFloat, CGFloat)] = isPad
    ? [("light.png", 166, 730), ("dark.png", 658, 1020)]
    : [("light.png", 105, 790), ("dark.png", 455, 1150)]
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
let options = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "availability"
let headline = options ? ["Use your calendar.", "Or set your own hours."] : ["Light or dark.", "Make it yours."]
for (index, value) in headline.enumerated() {
    let text = NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.055, alpha: 1), .kern: -2.2
    ])
    precondition(text.size().width < CGFloat(width) - 160)
    text.draw(at: CGPoint(x: (CGFloat(width) - text.size().width) / 2,
                         y: titleTop + CGFloat(index) * lineHeight))
}
// Dark is drawn last, in front of Light. No appearance labels.
for (name, x, y) in frames {
    let source = CGImageSourceCreateWithURL(dir.appendingPathComponent(name) as CFURL, nil)!
    let capture = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let screenHeight = screenWidth * CGFloat(capture.height) / CGFloat(capture.width)
    let rect = CGRect(x: x, y: y, width: screenWidth, height: screenHeight)
    let frame = rect.insetBy(dx: -frameWidth, dy: -frameWidth)
    context.addPath(CGPath(roundedRect: frame, cornerWidth: radius + frameWidth - (isPad ? 0 : 1),
                          cornerHeight: radius + frameWidth - (isPad ? 0 : 1), transform: nil))
    context.setFillColor(CGColor(gray: 0.12, alpha: 1)); context.fillPath()
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip(); context.interpolationQuality = .high
    NSImage(cgImage: capture, size: NSSize(width: capture.width, height: capture.height))
        .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
              hints: [.interpolation: NSImageInterpolation.high])
    context.restoreGState()
}
NSGraphicsContext.restoreGraphicsState()
let output = dir.appendingPathComponent("pair.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print(output.path)
