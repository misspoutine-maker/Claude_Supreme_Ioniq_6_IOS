import SwiftUI

let appVersion = "iOS v1 - phase 1 (OBD + GPS + Live)"

struct RootView: View {
    @EnvironmentObject var obd: ObdBle
    @EnvironmentObject var gps: LocationTracker
    @State private var tab = 0
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let items: [(String, String)] = [("Live", "🚗"), ("Today", "📅"), ("History", "🕘"), ("More", "☰")]

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                LinearGradient(colors: [Pal.bg, Pal.bg2], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                if landscape {
                    HStack(spacing: 0) {
                        navBar(vertical: true)
                        content(landscape: true, size: geo.size)
                    }
                } else {
                    VStack(spacing: 0) {
                        content(landscape: false, size: geo.size)
                        navBar(vertical: false)
                    }
                }
            }
        }
        .onReceive(clock) { t in
            now = t
            // Le GPS indique à l'OBD si la voiture roule (distingue régénération et recharge).
            if let loc = gps.lastLocation {
                obd.moving = t.timeIntervalSince(loc.timestamp) < 15 && (gps.speedKph ?? 0) > 3.0
            } else { obd.moving = false }
        }
        .onAppear {
            gps.start()
            if !obd.isActive() { obd.connect() }
        }
    }

    @ViewBuilder
    private func content(landscape: Bool, size: CGSize) -> some View {
        switch tab {
        case 0: LiveView(now: now, landscape: landscape, availH: size.height - 16, availW: size.width, onSettings: { tab = 3 }, onExit: exitApp)
        case 3: MoreView(onExit: exitApp)
        default: PlaceholderView(title: tab == 1 ? "Today" : "History")
        }
    }

    private func navBar(vertical: Bool) -> some View {
        let buttons = ForEach(0..<items.count, id: \.self) { i in
            Button { tab = i } label: {
                VStack(spacing: 2) {
                    Text(items[i].1).font(.system(size: 20))
                    Text(items[i].0).font(.system(size: 11))
                }
                .foregroundColor(tab == i ? Pal.blue : Pal.muted)
                .frame(maxWidth: vertical ? 64 : .infinity, minHeight: 48)
                .background(tab == i ? Pal.blue.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        return Group {
            if vertical { VStack(spacing: 8) { buttons; Spacer() }.padding(.top, 12).frame(width: 72) }
            else { HStack(spacing: 4) { buttons }.padding(.horizontal, 8).padding(.vertical, 4) }
        }
        .background(Pal.bg2.ignoresSafeArea())
    }

    private func exitApp() {
        obd.disconnect()
        gps.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
    }
}

struct PlaceholderView: View {
    let title: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 24, weight: .bold)).foregroundColor(Pal.text)
            Text("Coming in the next phase").font(.system(size: 13)).foregroundColor(Pal.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Live

struct LiveView: View {
    @EnvironmentObject var obd: ObdBle
    @EnvironmentObject var gps: LocationTracker
    let now: Date
    let landscape: Bool
    let availH: CGFloat
    let availW: CGFloat
    let onSettings: () -> Void
    let onExit: () -> Void

    private var consumption: Double? {
        gps.totalDistanceKm > 0.3 ? obd.dischargeEnergyKwh * 100 / gps.totalDistanceKm : nil
    }
    private var region: String { [gps.adminArea, gps.country].compactMap { $0 }.joined(separator: ", ") }
    private var altText: String {
        "🏔 Altitude: " + ((gps.altitudeBaroM ?? gps.altitudeM).map { String(format: "%.0f m", $0) } ?? "--")
    }
    private var ageSec: Int? { obd.lastData.map { Int(now.timeIntervalSince($0)) } }
    private var socNote: String {
        var s = "Dashboard SOC"
        if let b = obd.socBms { s += String(format: " - BMS %.1f %%", b) }
        if let a = ageSec { s += a <= 5 ? " - live" : " - last data \(a)s ago" }
        return s
    }
    private var socWarn: Bool { (ageSec ?? 0) > 10 }
    private var maxKph: Double? { gps.maxSpeedKph > 0 ? gps.maxSpeedKph : nil }

    var body: some View {
        if landscape { landscapeBody } else { portraitBody }
    }

    private func fmt0(_ v: Double?) -> String { v.map { String(format: "%.0f", $0) } ?? "--" }

    private func speedStats(avg: Double?, max: Double?, unit: String) -> some View {
        DarkCard(padding: 8) {
            HStack {
                ForEach([("Average", avg), ("Max", max)], id: \.0) { item in
                    VStack(spacing: 1) {
                        Text(item.0).font(.system(size: 11)).foregroundColor(Pal.muted)
                        Text(fmt0(item.1)).font(.system(size: 22, weight: .bold)).foregroundColor(Pal.text)
                        Text(unit).font(.system(size: 11)).foregroundColor(Pal.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func socInfo(compact: Bool) -> some View {
        let temp: String = {
            guard let mx = obd.battTempMax, let mn = obd.battTempMin else { return "--" }
            return mn == mx ? "\(mx)" : "\(mn)-\(mx)"
        }()
        let tempColor: Color = {
            guard let mx = obd.battTempMax else { return Pal.muted }
            if mx >= 45 { return Pal.red }
            if (obd.battTempMin ?? mx) <= 5 { return Pal.blue }
            return Pal.muted
        }()
        return VStack(alignment: .leading, spacing: compact ? 3 : 8) {
            Text("⚡ Power").font(.system(size: 12)).foregroundColor(Pal.muted)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(obd.powerKw.map { String(format: "%.1f", $0) } ?? "--")
                    .font(.system(size: compact ? 28 : 34, weight: .bold))
                    .foregroundColor((obd.powerKw ?? 0) < -0.5 ? Pal.green : Pal.text)
                Text("kW").font(.system(size: 14)).foregroundColor(Pal.muted)
            }
            Divider().background(Pal.cardBorder)
            Text("Consumption").font(.system(size: 12)).foregroundColor(Pal.muted)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(consumption.map { String(format: "%.1f", $0) } ?? "--")
                    .font(.system(size: compact ? 16 : 20, weight: .bold)).foregroundColor(Pal.text)
                Text("kWh/100km").font(.system(size: 11)).foregroundColor(Pal.muted)
            }
            Text("🌡 \(temp) °C").font(.system(size: 12)).foregroundColor(tempColor)
        }
    }

    @ViewBuilder private var chargingCard: some View {
        if obd.isCharging {
            DarkCard(border: Pal.green, padding: 10) {
                Text("⚡ Charging").font(.system(size: 15, weight: .bold)).foregroundColor(Pal.green)
                StatStrip(items: [
                    ("Average", obd.chargeAvgKw.map { String(format: "%.1f kW", $0) } ?? "--"),
                    ("Max", obd.chargeMaxKw.map { String(format: "%.1f kW", $0) } ?? "--"),
                    ("Energy", String(format: "%.2f kWh", obd.chargeEnergyKwh))
                ]).padding(.top, 4)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("📍").font(.system(size: landscape ? 18 : 30))
            VStack(alignment: .leading, spacing: 1) {
                Text(gps.city ?? "--").font(.system(size: landscape ? 20 : 28, weight: .bold)).foregroundColor(Pal.text).lineLimit(1)
                if !region.isEmpty && !landscape { Text(region).font(.system(size: 14)).foregroundColor(Pal.muted) }
                Text(landscape ? ([region, altText].filter { !$0.isEmpty }.joined(separator: "  -  ")) : altText)
                    .font(.system(size: landscape ? 11 : 13)).foregroundColor(Pal.muted).lineLimit(1)
            }
            Spacer()
            Button(action: onSettings) { Text("⚙").font(.system(size: landscape ? 20 : 24)).foregroundColor(Pal.muted) }
            Button(action: onExit) { Text("Exit").font(.system(size: landscape ? 13 : 14)).foregroundColor(Pal.red) }
        }
    }

    private var portraitBody: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 6) {
                        SpeedGauge(value: gps.speedMph, maxValue: 160, majorStep: 20, unit: "mph", accent: Pal.blue)
                        speedStats(avg: gps.avgMovingSpeedKph.map { $0 / 1.60934 }, max: maxKph.map { $0 / 1.60934 }, unit: "mph")
                    }
                    VStack(spacing: 6) {
                        SpeedGauge(value: gps.speedKph, maxValue: 240, majorStep: 40, unit: "km/h", accent: Pal.green)
                        speedStats(avg: gps.avgMovingSpeedKph, max: maxKph, unit: "km/h")
                    }
                }
                DarkCard {
                    HStack(spacing: 14) {
                        SocGauge(soc: obd.soc).frame(maxWidth: .infinity)
                        Rectangle().fill(Pal.cardBorder).frame(width: 1, height: 130)
                        socInfo(compact: false).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(socNote).font(.system(size: 11)).foregroundColor(socWarn ? Pal.red : Pal.muted).padding(.top, 6)
                }
                chargingCard
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    private var landscapeBody: some View {
        let g = min(max(availH - 72, 110), 230, (availW * 0.55 - 12) / 2)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                header
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        SpeedGauge(value: gps.speedMph, maxValue: 160, majorStep: 20, unit: "mph", accent: Pal.blue)
                            .frame(width: g, height: g)
                        Text("Avg \(fmt0(gps.avgMovingSpeedKph.map { $0 / 1.60934 })) - Max \(fmt0(maxKph.map { $0 / 1.60934 })) mph")
                            .font(.system(size: 11)).foregroundColor(Pal.muted)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        SpeedGauge(value: gps.speedKph, maxValue: 240, majorStep: 40, unit: "km/h", accent: Pal.green)
                            .frame(width: g, height: g)
                        Text("Avg \(fmt0(gps.avgMovingSpeedKph)) - Max \(fmt0(maxKph)) km/h")
                            .font(.system(size: 11)).foregroundColor(Pal.muted)
                    }
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            ScrollView {
                VStack(spacing: 8) {
                    DarkCard(padding: 10) {
                        HStack(spacing: 10) {
                            SocGauge(soc: obd.soc).frame(width: 104, height: 104)
                            socInfo(compact: true).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(socNote).font(.system(size: 10)).foregroundColor(socWarn ? Pal.red : Pal.muted).padding(.top, 4)
                    }
                    chargingCard
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

// MARK: - More

struct MoreView: View {
    @EnvironmentObject var obd: ObdBle
    @EnvironmentObject var gps: LocationTracker
    let onExit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("More").font(.system(size: 24, weight: .bold)).foregroundColor(Pal.text)
                DarkCard {
                    Text("OBD adapter").font(.system(size: 15, weight: .bold)).foregroundColor(Pal.text)
                    Text(obd.state).font(.system(size: 12)).foregroundColor(Pal.muted).padding(.vertical, 4)
                    HStack(spacing: 8) {
                        Button("Connect OBD") { obd.connect() }.buttonStyle(.borderedProminent)
                        Button("Disconnect") { obd.disconnect() }.buttonStyle(.bordered)
                    }
                }
                DarkCard {
                    Text("GPS").font(.system(size: 15, weight: .bold)).foregroundColor(Pal.text)
                    Text(gps.running ? "Running (starts automatically with the app)." : "Stopped.")
                        .font(.system(size: 12)).foregroundColor(Pal.muted).padding(.vertical, 4)
                    HStack(spacing: 8) {
                        Button("Start GPS") { gps.start() }.buttonStyle(.bordered)
                        Button("Stop GPS") { gps.stop() }.buttonStyle(.bordered)
                    }
                }
                DarkCard {
                    Text("Diagnostics").font(.system(size: 15, weight: .bold)).foregroundColor(Pal.text)
                    ForEach(Array(obd.log.suffix(40).enumerated()), id: \.offset) { _, l in
                        Text(l).font(.system(size: 9, design: .monospaced)).foregroundColor(Pal.muted)
                    }
                }
                Button(action: onExit) {
                    Text("Exit app").foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Pal.red).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text(appVersion).font(.system(size: 11)).foregroundColor(Pal.muted).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }
}
