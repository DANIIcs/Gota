// Renders Gota's app icon at 1024 px. Regenerate the asset catalog with: scripts/make-icon.sh
import SwiftUI

/// Gota's app icon on Apple's 1024 grid: an 824 pt squircle with a glass water drop.
struct GotaIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.20, green: 0.62, blue: 1.0), Color(red: 0.05, green: 0.25, blue: 0.80)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .fill(RadialGradient(colors: [.white.opacity(0.35), .clear], center: UnitPoint(x: 0.3, y: 0.15), startRadius: 0, endRadius: 520))
                )
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 3))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 14)

            // The drop: white glass with a darker base and a bright highlight.
            Image(systemName: "drop.fill")
                .resizable().scaledToFit().frame(height: 500)
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.78, green: 0.90, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 0, green: 0.1, blue: 0.4).opacity(0.45), radius: 30, y: 22)
                .offset(y: 20)
            Ellipse()
                .fill(.white.opacity(0.85))
                .frame(width: 70, height: 130)
                .rotationEffect(.degrees(25))
                .blur(radius: 6)
                .offset(x: -85, y: 90)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: GotaIcon())
    renderer.scale = 1
    let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
