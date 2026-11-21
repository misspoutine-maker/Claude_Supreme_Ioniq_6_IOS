import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Color {
    /// Couleur qui s'adapte au thème (nuit / jour).
    init(dark: UInt32, light: UInt32) {
        self.init(UIColor { trait in
            let h = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255,
                           blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        })
    }
}

enum Pal {
    static let bg = Color(dark: 0x070B12, light: 0xF3F6FB)
    static let bg2 = Color(dark: 0x0D1522, light: 0xE3EAF5)
    static let card = Color(dark: 0x101826, light: 0xFFFFFF)
    static let cardBorder = Color(dark: 0x1F2D45, light: 0xB8C4D8)
    static let track = Color(dark: 0x16223A, light: 0xD3DCEB)
    static let text = Color(dark: 0xEAF0FA, light: 0x0A1220)
    static let muted = Color(dark: 0x8D9BB5, light: 0x44546E)
    static let blue = Color(dark: 0x2F8CFF, light: 0x0A58CA)
    static let green = Color(dark: 0x22E07A, light: 0x087F3E)
    static let orange = Color(dark: 0xFF9A2E, light: 0xC25E00)
    static let purple = Color(dark: 0x9B6BFF, light: 0x5B2FD0)
    static let red = Color(dark: 0xFF5A5F, light: 0xC8202A)
    static let gray = Color(dark: 0x9AA5B8, light: 0x4F5B72)
    static let teal = Color(dark: 0x17D4C0, light: 0x0A857A)
}

struct DarkCard<Content: View>: View {
    let border: Color
    let padding: CGFloat
    let content: Content

    init(border: Color = Pal.cardBorder, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.border = border
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Pal.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
    }
}

struct StatStrip: View {
    let items: [(String, String)]
    var body: some View {
        HStack {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.0).font(.system(size: 11)).foregroundColor(Pal.muted).multilineTextAlignment(.center)
                    Text(item.1).font(.system(size: 16, weight: .bold)).foregroundColor(Pal.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Arc de cadran : 270°, départ à 135° (en bas à gauche).
private struct GaugeArc: View {
    let frac: Double
    let color: Color
    let width: CGFloat
    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(0.75 * frac))
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(135))
            .padding(width)
    }
}

/// Cadran de vitesse : arc, graduations, aiguille.
struct SpeedGauge: View {
    let value: Double?
    let maxValue: Double
    let majorStep: Int
    let unit: String
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let stroke = s * 0.06
            let frac = min(max((value ?? 0) / maxValue, 0), 1)
            let c = s / 2
            let rOuter = s / 2 - stroke * 2
            let ticks = Array(stride(from: 0, through: Int(maxValue), by: majorStep))
            ZStack {
                GaugeArc(frac: 1, color: Pal.track, width: stroke)
                if frac > 0 { GaugeArc(frac: frac, color: accent, width: stroke) }
                ForEach(ticks, id: \.self) { t in
                    let ang = (135.0 + 270.0 * Double(t) / maxValue) * Double.pi / 180
                    Path { p in
                        p.move(to: CGPoint(x: c + CGFloat(cos(ang)) * rOuter, y: c + CGFloat(sin(ang)) * rOuter))
                        p.addLine(to: CGPoint(x: c + CGFloat(cos(ang)) * (rOuter - stroke * 0.8),
                                              y: c + CGFloat(sin(ang)) * (rOuter - stroke * 0.8)))
                    }
                    .stroke(Pal.muted, lineWidth: 1.5)
                    Text("\(t)")
                        .font(.system(size: s * 0.065))
                        .foregroundColor(Pal.muted)
                        .position(x: c + CGFloat(cos(ang)) * (rOuter - stroke * 2.3),
                                  y: c + CGFloat(sin(ang)) * (rOuter - stroke * 2.3))
                }
                let na = (135.0 + 270.0 * frac) * Double.pi / 180
                let needle = rOuter - stroke * 3.4
                Path { p in
                    p.move(to: CGPoint(x: c, y: c))
                    p.addLine(to: CGPoint(x: c + CGFloat(cos(na)) * needle, y: c + CGFloat(sin(na)) * needle))
                }
                .stroke(accent, style: StrokeStyle(lineWidth: stroke * 0.45, lineCap: .round))
                Circle().fill(Pal.bg2).frame(width: stroke * 2.6, height: stroke * 2.6).position(x: c, y: c)
                Circle().fill(accent).frame(width: stroke * 1.2, height: stroke * 1.2).position(x: c, y: c)
                VStack(spacing: 0) {
                    Text(value.map { String(format: "%.0f", $0) } ?? "--")
                        .font(.system(size: s * 0.14, weight: .bold)).foregroundColor(Pal.text)
                    Text(unit).font(.system(size: s * 0.065)).foregroundColor(Pal.muted)
                }
                .frame(width: s, height: s, alignment: .bottom)
                .padding(.bottom, 10)
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Cadran du SOC.
struct SocGauge: View {
    let soc: Double?
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let stroke = s * 0.09
            let frac = min(max((soc ?? 0) / 100, 0), 1)
            let accent: Color = soc == nil ? Pal.gray : (soc! < 20 ? Pal.red : (soc! < 50 ? Pal.orange : Pal.green))
            ZStack {
                GaugeArc(frac: 1, color: Pal.track, width: stroke)
                if frac > 0 { GaugeArc(frac: frac, color: accent, width: stroke) }
                VStack(spacing: 0) {
                    Text("🔋").font(.system(size: s * 0.14))
                    Text("SOC").font(.system(size: s * 0.1)).foregroundColor(Pal.muted)
                    Text(soc.map { String(format: "%.1f%%", $0) } ?? "--")
                        .font(.system(size: s * 0.17, weight: .bold)).foregroundColor(Pal.text)
                }
            }
            .frame(width: s, height: s)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct IconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 40
    var body: some View {
        Text(icon).font(.system(size: size * 0.45))
            .frame(width: size, height: size)
            .background(color.opacity(0.22))
            .clipShape(Circle())
            .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1))
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let accent: Color
    let active: Bool
    let enabled: Bool
    var timer: String? = nil
    var timerActive = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 22)).foregroundColor(accent)
                    .frame(width: 58, height: 58)
                    .background(accent.opacity(active ? 0.35 : 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent, lineWidth: 1.5))
                Text(label).font(.system(size: 11)).foregroundColor(Pal.text)
                    .multilineTextAlignment(.center).lineLimit(2)
                if let timer {
                    Text(timer).font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(timerActive ? accent : Pal.muted)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
