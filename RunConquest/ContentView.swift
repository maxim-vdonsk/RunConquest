import SwiftUI
import UserNotifications

// MARK: - Animated HUD Stat

struct AnimatedHUDStat: View {
    let value: String
    let unit: String
    let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(unit)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(color.opacity(0.5))
                .tracking(1)
        }
        .frame(minWidth: 46)
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var realtimeManager = RealtimeManager()
    @State private var healthKit = HealthKitManager()

    @AppStorage("playerName") private var savedName: String = ""
    @AppStorage("playerColor") private var savedColor: String = "orange"
    @AppStorage("isRunActive") private var isRunActive: Bool = false

    @Environment(AppLanguage.self) private var lang

    @State private var showSetup = false
    @State private var showResults = false
    @State private var showProfile = false
    @State private var showLeaderboard = false
    @State private var isSaving = false
    @State private var attackedIds: Set<String> = []
    @State private var attackAlert: String? = nil
    @State private var attackedCount = 0
    @State private var showAttackFlash = false
    @State private var pulseTracking = false
    @State private var finishedRunId: String? = nil
    @State private var finalElapsed: Int = 0

    var accent: Color { Neon.colorMap[savedColor] ?? Neon.cyan }

    var points: Int {
        Int(locationManager.distanceMeters / 10)
        + Int(locationManager.conqueredArea / 100)
        + attackedCount * 50
    }

    var heartRateColor: Color {
        switch healthKit.heartRate {
        case 0..<100:  return .white
        case 100..<130:return Neon.green
        case 130..<160:return Neon.orange
        default:       return Neon.red
        }
    }

    var body: some View {
        ZStack {
            if showSetup || savedName.isEmpty {
                SetupView(playerName: $savedName, selectedColor: $savedColor) {
                    UserDefaults.standard.set(savedName, forKey: "playerName")
                    UserDefaults.standard.set(savedColor, forKey: "playerColor")
                    showSetup = false
                    isRunActive = true
                    locationManager.startTracking()
                    realtimeManager.connect()
                    if healthKit.isAvailable {
                        Task { await healthKit.requestAuthorization() }
                        healthKit.startWorkout()
                    }
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            } else if showResults {
                ResultsView(
                    playerName: savedName,
                    distance: locationManager.distanceMeters,
                    area: locationManager.conqueredArea,
                    points: points,
                    color: savedColor,
                    attackedCount: attackedCount,
                    elapsedSeconds: finalElapsed,
                    avgPaceSec: locationManager.avgPaceSec,
                    avgHeartRate: healthKit.heartRate,
                    calories: Int(healthKit.calories),
                    splits: locationManager.splits,
                    runId: finishedRunId,
                    onRestart: {
                        realtimeManager.disconnect()
                        attackedIds = []; attackedCount = 0; finishedRunId = nil; finalElapsed = 0
                        isRunActive = true
                        withAnimation { showResults = false }
                        locationManager.startTracking()
                        realtimeManager.connect()
                        healthKit.startWorkout()
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            } else {
                runScreen
                    .transition(.opacity)
                    .onAppear {
                        if !locationManager.isTracking {
                            isRunActive = true
                            locationManager.startTracking()
                            realtimeManager.connect()
                            Task { await healthKit.requestAuthorization() }
                            healthKit.startWorkout()
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSetup)
        .animation(.easeInOut(duration: 0.4), value: showResults)
        .sheet(isPresented: $showProfile) {
            ProfileView(playerName: savedName, color: savedColor, savedName: $savedName, savedColor: $savedColor)
        }
        .sheet(isPresented: $showLeaderboard) { LeaderboardView(currentPlayer: savedName) }
    }

    // MARK: - Run Screen

    private var runScreen: some View {
        ZStack {
            RunMapView(
                region: $locationManager.region,
                routeCoordinates: locationManager.routeCoordinates,
                otherRuns: realtimeManager.otherRuns,
                myColor: savedColor,
                attackedIds: attackedIds
            )
            .ignoresSafeArea()
            .onChange(of: locationManager.routeCoordinates.count) { checkAttacks() }

            if showAttackFlash {
                Neon.red.opacity(0.2).ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: showAttackFlash)
            }

            CornerBrackets(color: accent)

            VStack(spacing: 0) {
                topHUD
                attackBanner
                Spacer()
                liveStatsBar
                stopButton
            }
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        HStack(spacing: 8) {
            // Avatar
            Button(action: { showProfile = true }) {
                ZStack {
                    Circle().fill(accent.opacity(0.15)).frame(width: 42, height: 42)
                        .shadow(color: accent.opacity(0.6), radius: 8)
                    Circle().stroke(accent.opacity(0.7), lineWidth: 1.5).frame(width: 42, height: 42)
                    Text(String(savedName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(accent).shadow(color: accent, radius: 4)
                }
            }

            // Stats block
            HStack(spacing: 0) {
                AnimatedHUDStat(
                    value: String(format: "%.2f", locationManager.distanceMeters / 1000),
                    unit: "KM", color: .white
                )
                hudDivider
                AnimatedHUDStat(
                    value: locationManager.formattedPace.isEmpty || locationManager.currentPaceSec == 0
                           ? "--:--" : locationManager.formattedPace,
                    unit: lang.t("PACE", "ТЕМП"), color: speedColor
                )
                hudDivider
                AnimatedHUDStat(
                    value: locationManager.formattedElapsed,
                    unit: lang.t("TIME", "ВРЕМЯ"), color: .white
                )
                hudDivider
                AnimatedHUDStat(
                    value: "\(points)",
                    unit: lang.t("PTS", "ОЧК"), color: accent
                )
                if healthKit.heartRate > 0 {
                    hudDivider
                    AnimatedHUDStat(
                        value: "\(healthKit.heartRate)",
                        unit: "BPM", color: heartRateColor
                    )
                }
                if attackedCount > 0 {
                    hudDivider
                    AnimatedHUDStat(value: "⚔\(attackedCount)", unit: lang.t("HITS", "УДА"), color: Neon.red)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.8))
            .background(Neon.bg.opacity(0.7))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.3), lineWidth: 1))

            Spacer()

            // Leaderboard
            Button(action: { showLeaderboard = true }) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Neon.orange)
                    .shadow(color: Neon.orange.opacity(0.8), radius: 6)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .background(Neon.bg.opacity(0.7))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Neon.orange.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal).padding(.top, 8)
    }

    // MARK: - Attack Banner

    @ViewBuilder
    private var attackBanner: some View {
        if let alert = attackAlert {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundColor(Neon.red).shadow(color: Neon.red, radius: 4)
                Text(alert.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white).tracking(1)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Neon.red.opacity(0.15))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Neon.red.opacity(0.7), lineWidth: 1))
            .shadow(color: Neon.red.opacity(0.5), radius: 10)
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding(.top, 6)
        }
    }

    // MARK: - Live Stats Bar (km splits indicator)

    private var liveStatsBar: some View {
        HStack(spacing: 12) {
            if !locationManager.splits.isEmpty {
                let last = locationManager.splits.last!
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Neon.green)
                    Text(lang.t("KM \(last.kmIndex):", "КМ \(last.kmIndex):"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(formatPace(seconds: last.paceSec))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.green)
                        .shadow(color: Neon.green.opacity(0.5), radius: 3)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Neon.surface.opacity(0.9))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Neon.green.opacity(0.3), lineWidth: 1))
            }

            if healthKit.calories > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Neon.orange)
                    Text("\(Int(healthKit.calories)) \(lang.t("kcal", "ккал"))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.orange)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Neon.surface.opacity(0.9))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Neon.orange.opacity(0.3), lineWidth: 1))
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button(action: handleStop) {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text(lang.t("SYNCING...", "СИНХРОНИЗАЦИЯ..."))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white).tracking(2)
                } else {
                    Image(systemName: "stop.fill").foregroundColor(.white)
                    Text(lang.t("[ TERMINATE RUN ]", "[ ЗАВЕРШИТЬ ЗАБЕГ ]"))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white).tracking(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Neon.red.opacity(0.85))
            .cornerRadius(4)
            .shadow(color: Neon.red.opacity(pulseTracking ? 0.8 : 0.3), radius: pulseTracking ? 18 : 6)
            .scaleEffect(pulseTracking ? 1.01 : 1.0)
            .padding(.horizontal)
        }
        .disabled(isSaving)
        .padding(.bottom, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulseTracking = true
            }
        }
    }

    // MARK: - Helpers

    private var hudDivider: some View {
        Rectangle().fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 24).padding(.horizontal, 2)
    }

    var speedColor: Color {
        switch locationManager.currentSpeed {
        case 0..<6:   return .white
        case 6..<10:  return Neon.green
        case 10..<14: return Neon.orange
        default:      return Neon.red
        }
    }

    // MARK: - Attack Logic

    func checkAttacks() {
        let newIds = detectAttacks(
            myCoords: locationManager.routeCoordinates,
            otherRuns: realtimeManager.otherRuns.filter { $0.player_name != savedName }
        )
        for id in newIds {
            guard !attackedIds.contains(id) else { continue }
            attackedIds.insert(id); attackedCount += 1
            if let run = realtimeManager.otherRuns.first(where: { $0.id == id }) {
                attackAlert = lang.t("ATTACKING ZONE: \(run.player_name)", "ЗАХВАТ ЗОНЫ: \(run.player_name)")
                showAttackFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAttackFlash = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { attackAlert = nil }
                let content = UNMutableNotificationContent()
                content.title = lang.t("⚔ ATTACK", "⚔ АТАКА")
                content.body  = lang.t("Capturing territory of \(run.player_name)", "Захват территории \(run.player_name)")
                content.sound = .default
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                )
            }
        }
    }

    // MARK: - Stop Handler

    func handleStop() {
        locationManager.stopTracking()
        isRunActive = false
        isSaving = true
        let capturedDistance  = locationManager.distanceMeters
        let capturedArea      = locationManager.conqueredArea
        let capturedSplits    = locationManager.splits
        let capturedAvgPace   = locationManager.avgPaceSec
        let capturedElapsed   = locationManager.elapsedSeconds
        let capturedHR        = healthKit.heartRate
        let capturedPts       = points

        healthKit.stopWorkout(distance: capturedDistance) { elapsedSec in
            Task {
                let kcal = Int(self.healthKit.calories)
                let runId = await SupabaseService.shared.saveRun(
                    playerName: self.savedName,
                    coordinates: self.locationManager.routeCoordinates,
                    color: self.savedColor,
                    totalTime: elapsedSec > 0 ? elapsedSec : capturedElapsed,
                    avgPace: capturedAvgPace,
                    avgHR: capturedHR,
                    calories: kcal,
                    points: capturedPts
                )

                // Сохраняем сплиты
                if let rid = runId, !capturedSplits.isEmpty {
                    let dbSplits = capturedSplits.map {
                        RunSplit(id: nil, run_id: rid, player_name: self.savedName,
                                 km_index: $0.kmIndex, duration_sec: $0.durationSec,
                                 pace_sec: $0.paceSec, heart_rate: $0.heartRate, created_at: nil)
                    }
                    await SupabaseService.shared.saveSplits(dbSplits)
                }

                // Деактивируем атакованные зоны
                if !self.attackedIds.isEmpty {
                    await SupabaseService.shared.deactivateRuns(ids: Array(self.attackedIds))
                }

                // Обновляем игрока
                await SupabaseService.shared.upsertPlayer(
                    name: self.savedName, distance: capturedDistance,
                    area: capturedArea, attacks: self.attackedCount, points: capturedPts
                )

                // Пост в ленту
                if let rid = runId {
                    await SupabaseService.shared.postRunActivity(
                        playerName: self.savedName, runId: rid,
                        distance: capturedDistance, area: capturedArea,
                        points: capturedPts, color: self.savedColor
                    )
                }

                await MainActor.run {
                    self.finishedRunId = runId
                    self.finalElapsed = capturedElapsed
                    self.isSaving = false
                    withAnimation { self.showResults = true }
                }
            }
        }
    }
}
