import SwiftUI
import Charts
import CoreLocation

// MARK: - Results

struct ResultsView: View {
    let playerName: String
    let distance: Double
    let area: Double
    let points: Int
    let color: String
    let attackedCount: Int
    let elapsedSeconds: Int
    let avgPaceSec: Int
    let avgHeartRate: Int
    let calories: Int
    let splits: [SplitData]
    let routeCoordinates: [CLLocationCoordinate2D]
    let runId: String?
    let onRestart: () -> Void

    @Environment(AppLanguage.self) private var lang
    @State private var appeared = false
    @State private var showReplay = false
    @State private var selectedSplit: SplitData? = nil

    var accent: Color { Neon.colorMap[color] ?? Neon.cyan }

    var levelData: (String, Color) {
        switch points {
        case 0..<100:    return (lang.t("ROOKIE",    "НОВИЧОК"),    .gray)
        case 100..<500:  return (lang.t("FIGHTER",   "БОЕЦ"),       Neon.cyan)
        case 500..<1000: return (lang.t("WARRIOR",   "ВОИН"),       Neon.orange)
        default:         return (lang.t("CONQUEROR", "ЗАВОЕВАТЕЛЬ"),Neon.magenta)
        }
    }

    var bestSplit: SplitData? { splits.min(by: { $0.paceSec < $1.paceSec }) }
    var worstSplit: SplitData? { splits.max(by: { $0.paceSec < $1.paceSec }) }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()
            CornerBrackets(color: accent)

            Circle().fill(accent.opacity(0.06))
                .frame(width: 300, height: 300).blur(radius: 70)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // MARK: Header
                    VStack(spacing: 6) {
                        NeonLabel(text: lang.t("// MISSION REPORT //", "// ОТЧЁТ МИССИИ //"), color: accent)
                        Text(lang.t("RUN COMPLETE", "ЗАБЕГ ЗАВЕРШЁН"))
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white).tracking(4)
                            .shadow(color: accent, radius: 8)
                        NeonDivider(color: accent).padding(.horizontal, 30)
                    }
                    .scaleEffect(appeared ? 1 : 0.9).opacity(appeared ? 1 : 0)
                    .padding(.top, 24)

                    // MARK: Rank Badge
                    rankBadge
                        .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)

                    // MARK: Key Metrics Grid
                    metricsGrid
                        .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)

                    // MARK: Pace Chart
                    if splits.count >= 2 {
                        paceChart
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                    }

                    // MARK: Splits Table
                    if !splits.isEmpty {
                        splitsTable
                            .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                    }

                    // MARK: Buttons
                    actionButtons
                        .offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
        .fullScreenCover(isPresented: $showReplay) {
            ReplayView(coordinates: routeCoordinates, color: color)
        }
    }

    // MARK: - Rank Badge

    private var rankBadge: some View {
        VStack(spacing: 4) {
            Text(levelData.0)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(levelData.1).tracking(6)
                .shadow(color: levelData.1, radius: 12)
            Text(lang.t("RANK ACHIEVED", "РАНГ ПОЛУЧЕН"))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(levelData.1.opacity(0.6)).tracking(4)
        }
        .padding(.vertical, 12).frame(maxWidth: .infinity)
        .background(levelData.1.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(levelData.1.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricTile(icon: "figure.run",
                           label: lang.t("DISTANCE", "ДИСТАНЦИЯ"),
                           value: String(format: "%.2f", distance / 1000),
                           unit: "KM", color: .white)
                MetricTile(icon: "clock.fill",
                           label: lang.t("TIME", "ВРЕМЯ"),
                           value: formatDuration(seconds: elapsedSeconds),
                           unit: "", color: .white)
            }
            HStack(spacing: 8) {
                MetricTile(icon: "speedometer",
                           label: lang.t("AVG PACE", "СР. ТЕМП"),
                           value: formatPace(seconds: avgPaceSec),
                           unit: lang.t("MIN/KM", "МИН/КМ"), color: accent)
                MetricTile(icon: "map.fill",
                           label: lang.t("TERRITORY", "ТЕРРИТОРИЯ"),
                           value: String(format: "%.0f", area),
                           unit: "M²", color: Neon.green)
            }
            HStack(spacing: 8) {
                if avgHeartRate > 0 {
                    MetricTile(icon: "heart.fill",
                               label: lang.t("AVG BPM", "СР. ПУЛЬС"),
                               value: "\(avgHeartRate)",
                               unit: "BPM", color: Neon.red)
                }
                if calories > 0 {
                    MetricTile(icon: "flame.fill",
                               label: lang.t("CALORIES", "КАЛОРИИ"),
                               value: "\(calories)",
                               unit: lang.t("KCAL", "ККАЛ"), color: Neon.orange)
                }
                if attackedCount > 0 {
                    MetricTile(icon: "bolt.fill",
                               label: lang.t("ATTACKS", "АТАКИ"),
                               value: "\(attackedCount)",
                               unit: lang.t("ZONES", "ЗОН"), color: Neon.red)
                }
            }
            // Score row
            HStack {
                Image(systemName: "star.fill").foregroundColor(accent)
                Text(lang.t("SCORE", "ОЧКИ"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6)).tracking(2)
                Spacer()
                Text("\(points) \(lang.t("PTS", "ОЧК"))")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(accent).shadow(color: accent.opacity(0.6), radius: 4)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(accent.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Pace Chart

    private var paceChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            NeonLabel(text: lang.t("> PACE CHART:", "> ГРАФИК ТЕМПА:"), color: accent)

            Chart {
                ForEach(splits) { split in
                    BarMark(
                        x: .value("KM", split.kmIndex),
                        y: .value(lang.t("Pace", "Темп"), split.paceSec > 0 ? split.paceSec : 0)
                    )
                    .foregroundStyle(barColor(for: split))
                    .cornerRadius(2)
                }
                if avgPaceSec > 0 {
                    RuleMark(y: .value(lang.t("Avg", "Ср."), avgPaceSec))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(accent.opacity(0.5))
                        .annotation(position: .trailing) {
                            Text(lang.t("AVG", "СР."))
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(accent.opacity(0.5))
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let sec = value.as(Int.self) {
                            Text(formatPace(seconds: sec))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        .foregroundStyle(Color.white.opacity(0.06))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let km = value.as(Int.self) {
                            Text("\(km)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.background(Neon.surface.opacity(0.3))
            }
            .frame(height: 120)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Neon.green, label: lang.t("Best km", "Лучший км"))
                legendDot(color: Neon.red,   label: lang.t("Worst km", "Худший км"))
                legendDot(color: accent,     label: lang.t("Other", "Остальные"))
            }
        }
        .padding(12)
        .background(Neon.surface.opacity(0.4))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.15), lineWidth: 1))
    }

    private func barColor(for split: SplitData) -> Color {
        if split.id == bestSplit?.id  { return Neon.green }
        if split.id == worstSplit?.id { return Neon.red }
        return accent.opacity(0.6)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.7), radius: 2)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
        }
    }

    // MARK: - Splits Table

    private var splitsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                NeonLabel(text: lang.t("> SPLITS:", "> СПЛИТЫ:"), color: accent)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(accent.opacity(0.06))

            // Column headers
            HStack {
                Text(lang.t("KM", "КМ"))
                    .frame(width: 30, alignment: .leading)
                Spacer()
                Text(lang.t("TIME", "ВРЕМЯ"))
                    .frame(width: 52, alignment: .trailing)
                Text(lang.t("PACE", "ТЕМП"))
                    .frame(width: 52, alignment: .trailing)
                if splits.contains(where: { $0.heartRate != nil }) {
                    Text("BPM")
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(.gray.opacity(0.4))
            .tracking(1)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Neon.surface.opacity(0.3))

            // Rows
            ForEach(splits) { split in
                splitRow(split)
            }
        }
        .background(Neon.surface.opacity(0.4))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.15), lineWidth: 1))
    }

    private func splitRow(_ split: SplitData) -> some View {
        let isBest  = split.id == bestSplit?.id
        let isWorst = split.id == worstSplit?.id
        let rowAccent: Color = isBest ? Neon.green : (isWorst ? Neon.red : .white)

        return HStack {
            HStack(spacing: 4) {
                if isBest  { Image(systemName: "arrow.up").font(.system(size: 7)).foregroundColor(Neon.green) }
                if isWorst { Image(systemName: "arrow.down").font(.system(size: 7)).foregroundColor(Neon.red) }
                Text("\(split.kmIndex)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(rowAccent)
            }
            .frame(width: 30, alignment: .leading)

            Spacer()

            Text(formatDuration(seconds: split.durationSec))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .frame(width: 52, alignment: .trailing)

            Text(formatPace(seconds: split.paceSec))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(rowAccent)
                .shadow(color: (isBest || isWorst) ? rowAccent.opacity(0.5) : .clear, radius: 3)
                .frame(width: 52, alignment: .trailing)

            if splits.contains(where: { $0.heartRate != nil }) {
                Text(split.heartRate.map { "\($0)" } ?? "--")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Neon.red.opacity(split.heartRate != nil ? 0.8 : 0.3))
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(isBest ? Neon.green.opacity(0.05) : (isWorst ? Neon.red.opacity(0.05) : Color.white.opacity(0.02)))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Replay button
            Button(action: { showReplay = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill").foregroundColor(accent)
                    Text(lang.t("[ REPLAY RUN ]", "[ ПОВТОР ЗАБЕГА ]"))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(accent).tracking(2)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent.opacity(0.1))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.5), lineWidth: 1))
            }

            // New Mission button
            Button(action: onRestart) {
                Text(lang.t("[ NEW MISSION  ▶ ]", "[ НОВАЯ МИССИЯ  ▶ ]"))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Neon.bg).tracking(2)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(accent)
                    .cornerRadius(4)
                    .shadow(color: accent.opacity(0.7), radius: 14)
            }
        }
    }
}

// MARK: - Metric Tile

struct MetricTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color).font(.system(size: 16))
                .shadow(color: color.opacity(0.5), radius: 4)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5)).tracking(1)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(color)
                        .shadow(color: color == .white ? .clear : color.opacity(0.4), radius: 3)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(color.opacity(0.5))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Neon.surface.opacity(0.6))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Terminal Row (kept for backwards compat)

struct TerminalRow: View {
    let key: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6)).frame(width: 120, alignment: .leading)
            Text("//")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.3))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color == .white ? .clear : color.opacity(0.6), radius: 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.white.opacity(0.02))
    }
}
