import SwiftUI

// MARK: - Training Plan Models

struct TrainingPlan: Identifiable {
    let id: String
    let nameEN: String
    let nameRU: String
    let descEN: String
    let descRU: String
    let weeks: [TrainingWeek]
    let goalDistanceKm: Double
    let icon: String
    let color: Color
}

struct TrainingWeek: Identifiable {
    let id: Int
    let sessions: [TrainingSession]
    var totalKm: Double { sessions.reduce(0) { $0 + $1.distanceKm } }
}

struct TrainingSession: Identifiable {
    let id: Int
    let dayOfWeek: Int       // 1 = Mon … 7 = Sun
    let type: SessionType
    let distanceKm: Double
    let durationMin: Int
    let descEN: String
    let descRU: String

    enum SessionType: String {
        case easy      = "easy"
        case tempo     = "tempo"
        case interval  = "interval"
        case long      = "long"
        case rest      = "rest"

        var iconEN: String {
            switch self {
            case .easy:     return "EASY RUN"
            case .tempo:    return "TEMPO RUN"
            case .interval: return "INTERVALS"
            case .long:     return "LONG RUN"
            case .rest:     return "REST DAY"
            }
        }
        var iconRU: String {
            switch self {
            case .easy:     return "ЛЁГКИЙ БЕГ"
            case .tempo:    return "ТЕМПОВЫЙ"
            case .interval: return "ИНТЕРВАЛЫ"
            case .long:     return "ДЛИННЫЙ БЕГ"
            case .rest:     return "ОТДЫХ"
            }
        }
        var color: Color {
            switch self {
            case .easy:     return Neon.green
            case .tempo:    return Neon.orange
            case .interval: return Neon.red
            case .long:     return Neon.cyan
            case .rest:     return Color.gray
            }
        }
    }
}

// MARK: - Plan Storage

class PlanProgress: ObservableObject {
    static let shared = PlanProgress()

    @Published var activePlanId: String?     = UserDefaults.standard.string(forKey: "activePlanId")
    @Published var activeWeekIndex: Int      = UserDefaults.standard.integer(forKey: "activePlanWeek")
    @Published var completedSessionIds: Set<String> = {
        let arr = UserDefaults.standard.stringArray(forKey: "completedSessions") ?? []
        return Set(arr)
    }()

    func startPlan(_ id: String) {
        activePlanId = id; activeWeekIndex = 0; completedSessionIds = []
        save()
    }

    func completeSession(_ sessionKey: String) {
        completedSessionIds.insert(sessionKey)
        UserDefaults.standard.set(Array(completedSessionIds), forKey: "completedSessions")
    }

    func advanceWeek() {
        activeWeekIndex += 1
        UserDefaults.standard.set(activeWeekIndex, forKey: "activePlanWeek")
    }

    func abandonPlan() {
        activePlanId = nil; activeWeekIndex = 0; completedSessionIds = []
        save()
    }

    private func save() {
        UserDefaults.standard.set(activePlanId, forKey: "activePlanId")
        UserDefaults.standard.set(activeWeekIndex, forKey: "activePlanWeek")
        UserDefaults.standard.set(Array(completedSessionIds), forKey: "completedSessions")
    }
}

// MARK: - Plan Library

struct PlanLibrary {
    static let plans: [TrainingPlan] = [plan5K, plan10K, planHalf, planMarathon]

    // MARK: 5K — 6 weeks
    static let plan5K = TrainingPlan(
        id: "5k", nameEN: "5K PLAN", nameRU: "ПЛАН 5 КМ",
        descEN: "6-week beginner plan to complete your first 5K run",
        descRU: "6-недельный план для первого забега на 5 км",
        weeks: (0..<6).map { w in
            TrainingWeek(id: w, sessions: [
                TrainingSession(id: w*10+1, dayOfWeek: 1, type: .easy,
                    distanceKm: Double(w) * 0.5 + 2.0, durationMin: (w*3+15),
                    descEN: "Easy pace, conversational", descRU: "Лёгкий темп, разговорный"),
                TrainingSession(id: w*10+2, dayOfWeek: 3, type: .interval,
                    distanceKm: Double(w) * 0.3 + 1.5, durationMin: (w*2+20),
                    descEN: "4x400m at 5K pace with 90s rest", descRU: "4×400м в темпе 5К, отдых 90 сек"),
                TrainingSession(id: w*10+3, dayOfWeek: 5, type: .rest,
                    distanceKm: 0, durationMin: 0,
                    descEN: "Active recovery or rest", descRU: "Активное восстановление или отдых"),
                TrainingSession(id: w*10+4, dayOfWeek: 6, type: w < 4 ? .easy : .long,
                    distanceKm: Double(w) * 0.4 + 3.0, durationMin: (w*4+20),
                    descEN: "Weekend long run", descRU: "Длинный бег на выходных")
            ])
        },
        goalDistanceKm: 5, icon: "hare.fill", color: Neon.green
    )

    // MARK: 10K — 8 weeks
    static let plan10K = TrainingPlan(
        id: "10k", nameEN: "10K PLAN", nameRU: "ПЛАН 10 КМ",
        descEN: "8-week plan to conquer the 10K distance",
        descRU: "8-недельный план для забега на 10 км",
        weeks: (0..<8).map { w in
            TrainingWeek(id: w, sessions: [
                TrainingSession(id: w*10+1, dayOfWeek: 1, type: .easy,
                    distanceKm: Double(w) * 0.6 + 4.0, durationMin: w*3+25,
                    descEN: "Easy aerobic run", descRU: "Лёгкий аэробный бег"),
                TrainingSession(id: w*10+2, dayOfWeek: 3, type: .tempo,
                    distanceKm: Double(w) * 0.4 + 3.0, durationMin: w*2+25,
                    descEN: "Tempo run at comfortably hard pace", descRU: "Темповый бег в комфортно-тяжёлом темпе"),
                TrainingSession(id: w*10+3, dayOfWeek: 5, type: .interval,
                    distanceKm: Double(w) * 0.3 + 2.5, durationMin: w*3+25,
                    descEN: "6x800m at 10K pace", descRU: "6×800м в темпе 10К"),
                TrainingSession(id: w*10+4, dayOfWeek: 7, type: .long,
                    distanceKm: Double(w) * 0.7 + 6.0, durationMin: w*5+40,
                    descEN: "Long slow distance run", descRU: "Длинный медленный бег")
            ])
        },
        goalDistanceKm: 10, icon: "figure.run.circle.fill", color: Neon.cyan
    )

    // MARK: Half Marathon — 12 weeks
    static let planHalf = TrainingPlan(
        id: "half", nameEN: "HALF MARATHON", nameRU: "ПОЛУМАРАФОН",
        descEN: "12-week plan for the 21.1K distance",
        descRU: "12-недельный план для 21,1 км",
        weeks: (0..<12).map { w in
            TrainingWeek(id: w, sessions: [
                TrainingSession(id: w*10+1, dayOfWeek: 1, type: .easy,
                    distanceKm: Double(w) * 0.5 + 6.0, durationMin: w*3+35,
                    descEN: "Recovery easy run", descRU: "Восстановительный лёгкий бег"),
                TrainingSession(id: w*10+2, dayOfWeek: 3, type: .tempo,
                    distanceKm: Double(w) * 0.4 + 5.0, durationMin: w*2+30,
                    descEN: "Tempo run building lactate threshold", descRU: "Темповый — развитие лактатного порога"),
                TrainingSession(id: w*10+3, dayOfWeek: 5, type: .easy,
                    distanceKm: Double(w) * 0.3 + 5.0, durationMin: w*2+30,
                    descEN: "Easy run with strides", descRU: "Лёгкий бег с ускорениями"),
                TrainingSession(id: w*10+4, dayOfWeek: 7, type: .long,
                    distanceKm: min(Double(w) * 1.0 + 10.0, 19.0), durationMin: min(w*7+60, 130),
                    descEN: "Long run — key session of the week", descRU: "Длинный бег — главная тренировка недели")
            ])
        },
        goalDistanceKm: 21.1, icon: "medal.fill", color: Neon.orange
    )

    // MARK: Marathon — 16 weeks
    static let planMarathon = TrainingPlan(
        id: "marathon", nameEN: "MARATHON", nameRU: "МАРАФОН",
        descEN: "16-week plan for the full 42.2K marathon",
        descRU: "16-недельный план для полного марафона 42,2 км",
        weeks: (0..<16).map { w in
            TrainingWeek(id: w, sessions: [
                TrainingSession(id: w*10+1, dayOfWeek: 1, type: .easy,
                    distanceKm: Double(w) * 0.5 + 8.0, durationMin: w*3+45,
                    descEN: "Easy recovery run", descRU: "Лёгкий восстановительный бег"),
                TrainingSession(id: w*10+2, dayOfWeek: 2, type: w < 8 ? .easy : .interval,
                    distanceKm: Double(w) * 0.3 + 6.0, durationMin: w*2+35,
                    descEN: w < 8 ? "Easy aerobic" : "Marathon-pace intervals", descRU: w < 8 ? "Лёгкий аэробный" : "Интервалы в марафонском темпе"),
                TrainingSession(id: w*10+3, dayOfWeek: 4, type: .tempo,
                    distanceKm: Double(w) * 0.4 + 6.0, durationMin: w*2+35,
                    descEN: "Tempo run", descRU: "Темповый бег"),
                TrainingSession(id: w*10+4, dayOfWeek: 6, type: .easy,
                    distanceKm: Double(w) * 0.3 + 6.0, durationMin: w*2+35,
                    descEN: "Easy day before long run", descRU: "Лёгкий день перед длинным"),
                TrainingSession(id: w*10+5, dayOfWeek: 7, type: .long,
                    distanceKm: min(Double(w) * 1.2 + 14.0, 34.0), durationMin: min(w*8+80, 210),
                    descEN: "Long run — the cornerstone session", descRU: "Длинный бег — основа плана")
            ])
        },
        goalDistanceKm: 42.2, icon: "trophy.fill", color: Neon.magenta
    )
}

// MARK: - Training Plan View

struct TrainingPlanView: View {
    @Environment(AppLanguage.self) private var lang
    @StateObject private var progress = PlanProgress.shared
    @State private var selectedPlan: TrainingPlan? = nil

    var activePlan: TrainingPlan? {
        guard let id = progress.activePlanId else { return nil }
        return PlanLibrary.plans.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// TRAINING PROGRAMS //", "// ПРОГРАММЫ ТРЕНИРОВОК //"))
                    Text(lang.t("PLANS", "ПЛАНЫ"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.cyan, radius: 8)
                    NeonDivider().padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Active plan banner
                        if let active = activePlan {
                            activePlanBanner(active)
                        }

                        // Plan cards
                        ForEach(PlanLibrary.plans) { plan in
                            PlanCard(
                                plan: plan,
                                isActive: plan.id == progress.activePlanId,
                                onTap: { selectedPlan = plan }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(item: $selectedPlan) { plan in
            PlanDetailView(plan: plan)
        }
    }

    private func activePlanBanner(_ plan: TrainingPlan) -> some View {
        let weekIdx = progress.activeWeekIndex
        let totalWeeks = plan.weeks.count
        let pct = totalWeeks > 0 ? Double(weekIdx) / Double(totalWeeks) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: plan.icon).foregroundColor(plan.color)
                    .shadow(color: plan.color.opacity(0.6), radius: 4)
                Text(lang.t(plan.nameEN, plan.nameRU))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(plan.color)
                Spacer()
                Text("\(lang.t("WEEK", "НЕДЕЛЯ")) \(weekIdx + 1)/\(totalWeeks)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Neon.surface).frame(height: 4)
                    Capsule().fill(plan.color)
                        .frame(width: geo.size.width * pct, height: 4)
                        .shadow(color: plan.color.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 4)

            // Current week sessions
            if weekIdx < plan.weeks.count {
                let week = plan.weeks[weekIdx]
                Text("\(lang.t("THIS WEEK:", "ЭТА НЕДЕЛЯ:")) \(String(format: "%.0f", week.totalKm)) KM")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5)).tracking(1)
            }
        }
        .padding(14)
        .background(plan.color.opacity(0.08))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(plan.color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: TrainingPlan
    let isActive: Bool
    let onTap: () -> Void

    @Environment(AppLanguage.self) private var lang

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(plan.color.opacity(0.15)).frame(width: 50, height: 50)
                    Image(systemName: plan.icon)
                        .font(.system(size: 22)).foregroundColor(plan.color)
                        .shadow(color: plan.color.opacity(0.7), radius: 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(lang.t(plan.nameEN, plan.nameRU))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        if isActive {
                            Text(lang.t("ACTIVE", "АКТИВЕН"))
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(plan.color)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(plan.color.opacity(0.15))
                                .cornerRadius(2)
                        }
                    }
                    Text(lang.t(plan.descEN, plan.descRU))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Label("\(plan.weeks.count) \(lang.t("wk", "нед."))", systemImage: "calendar")
                        Label("\(String(format: "%.0f", plan.goalDistanceKm)) KM", systemImage: "flag.fill")
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(plan.color.opacity(0.6))
                    .labelStyle(.titleAndIcon)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(plan.color.opacity(0.4))
            }
            .padding(14)
            .background(isActive ? plan.color.opacity(0.08) : Neon.surface.opacity(0.5))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(
                isActive ? plan.color.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

// MARK: - Plan Detail View

struct PlanDetailView: View {
    let plan: TrainingPlan
    @Environment(AppLanguage.self) private var lang
    @StateObject private var progress = PlanProgress.shared
    @Environment(\.dismiss) private var dismiss
    @State private var expandedWeek: Int? = 0

    var isActive: Bool { progress.activePlanId == plan.id }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).background(.ultraThinMaterial).cornerRadius(4)
                    }
                    Spacer()
                    Text(lang.t(plan.nameEN, plan.nameRU))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(plan.color).shadow(color: plan.color, radius: 6)
                    Spacer()
                    Image(systemName: plan.icon)
                        .font(.system(size: 18)).foregroundColor(plan.color)
                        .frame(width: 36)
                }
                .padding(.horizontal).padding(.top, 16).padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Description
                        Text(lang.t(plan.descEN, plan.descRU))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        NeonDivider(color: plan.color).padding(.horizontal, 40)

                        // Weeks
                        ForEach(plan.weeks) { week in
                            WeekRow(
                                week: week,
                                planId: plan.id,
                                isCurrentWeek: isActive && week.id == progress.activeWeekIndex,
                                isExpanded: expandedWeek == week.id,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedWeek = expandedWeek == week.id ? nil : week.id
                                    }
                                }
                            )
                        }

                        // Start / Stop button
                        if isActive {
                            Button(action: { progress.abandonPlan(); dismiss() }) {
                                Text(lang.t("[ ABANDON PLAN ]", "[ ПРЕКРАТИТЬ ПЛАН ]"))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Neon.red).tracking(2)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Neon.red.opacity(0.1)).cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Neon.red.opacity(0.4), lineWidth: 1))
                            }
                        } else {
                            Button(action: { progress.startPlan(plan.id); dismiss() }) {
                                Text(lang.t("[ START PLAN  ▶ ]", "[ НАЧАТЬ ПЛАН  ▶ ]"))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(Neon.bg).tracking(2)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(plan.color).cornerRadius(4)
                                    .shadow(color: plan.color.opacity(0.6), radius: 12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Week Row

struct WeekRow: View {
    let week: TrainingWeek
    let planId: String
    let isCurrentWeek: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    @Environment(AppLanguage.self) private var lang
    @StateObject private var progress = PlanProgress.shared

    var body: some View {
        VStack(spacing: 0) {
            // Week header
            Button(action: onToggle) {
                HStack {
                    Text("\(lang.t("WEEK", "НЕДЕЛЯ")) \(week.id + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(isCurrentWeek ? Neon.cyan : .white)
                    if isCurrentWeek {
                        Text(lang.t("← CURRENT", "← СЕЙЧАС"))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(Neon.cyan.opacity(0.7))
                    }
                    Spacer()
                    Text(String(format: "%.0f KM", week.totalKm))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(isCurrentWeek ? Neon.cyan.opacity(0.08) : Neon.surface.opacity(0.4))
            }

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(week.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(
            isCurrentWeek ? Neon.cyan.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func sessionRow(_ session: TrainingSession) -> some View {
        let key = "\(planId)-\(week.id)-\(session.id)"
        let done = progress.completedSessionIds.contains(key)

        return HStack(spacing: 12) {
            Circle().fill(done ? Neon.green : session.type.color.opacity(0.3))
                .frame(width: 8, height: 8)
                .shadow(color: done ? Neon.green.opacity(0.7) : .clear, radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t(session.type.iconEN, session.type.iconRU))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(done ? .gray.opacity(0.4) : session.type.color)
                Text(lang.t(session.descEN, session.descRU))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            if session.type != .rest {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f KM", session.distanceKm))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(done ? 0.3 : 0.7))
                    Text("\(session.durationMin) \(lang.t("min", "мин"))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }

            // Complete button
            if !done && session.type != .rest {
                Button(action: { progress.completeSession(key) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 18)).foregroundColor(session.type.color.opacity(0.6))
                }
            } else if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18)).foregroundColor(Neon.green.opacity(0.5))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
    }
}
