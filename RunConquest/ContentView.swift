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
        .frame(minWidth: 52)
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var realtimeManager = RealtimeManager()

    @AppStorage("playerName") private var savedName: String = ""
    @AppStorage("playerColor") private var savedColor: String = "orange"

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

    var accent: Color { Neon.colorMap[savedColor] ?? Neon.cyan }

    var points: Int {
        Int(locationManager.distanceMeters / 10) + Int(locationManager.conqueredArea / 100) + attackedCount * 50
    }

    var body: some View {
        ZStack {
            if showSetup || savedName.isEmpty {
                SetupView(playerName: $savedName, selectedColor: $savedColor) {
                    UserDefaults.standard.set(savedName, forKey: "playerName")
                    UserDefaults.standard.set(savedColor, forKey: "playerColor")
                    showSetup = false
                    locationManager.startTracking()
                    realtimeManager.connect()
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            } else if showResults {
                ResultsView(
                    playerName: savedName, distance: locationManager.distanceMeters,
                    area: locationManager.conqueredArea, points: points,
                    color: savedColor, attackedCount: attackedCount,
                    onRestart: {
                        realtimeManager.disconnect()
                        attackedIds = []; attackedCount = 0
                        withAnimation { showResults = false }
                        locationManager.startTracking()
                        realtimeManager.connect()
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
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

                    // Attack flash
                    if showAttackFlash {
                        Neon.red.opacity(0.2).ignoresSafeArea()
                            .transition(.opacity).animation(.easeInOut(duration: 0.2), value: showAttackFlash)
                    }

                    // Corner brackets overlay
                    CornerBrackets(color: accent)

                    VStack {
                        // Top HUD bar
                        HStack(spacing: 8) {
                            // Avatar button
                            Button(action: { showProfile = true }) {
                                ZStack {
                                    Circle()
                                        .fill(accent.opacity(0.15))
                                        .frame(width: 42, height: 42)
                                        .shadow(color: accent.opacity(0.6), radius: 8)
                                    Circle()
                                        .stroke(accent.opacity(0.7), lineWidth: 1.5)
                                        .frame(width: 42, height: 42)
                                    Text(String(savedName.prefix(1)).uppercased())
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundColor(accent)
                                        .shadow(color: accent, radius: 4)
                                }
                            }

                            // Stats HUD
                            HStack(spacing: 0) {
                                AnimatedHUDStat(value: String(format: "%.2f", locationManager.distanceMeters / 1000), unit: "KM", color: .white)
                                hudDivider
                                AnimatedHUDStat(value: String(format: "%.0f", locationManager.currentSpeed), unit: "KM/H", color: speedColor)
                                hudDivider
                                AnimatedHUDStat(value: "\(points)", unit: "PTS", color: accent)
                                if attackedCount > 0 {
                                    hudDivider
                                    AnimatedHUDStat(value: "⚔\(attackedCount)", unit: "HITS", color: Neon.red)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.ultraThinMaterial.opacity(0.8))
                            .background(Neon.bg.opacity(0.7))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.3), lineWidth: 1))

                            Spacer()

                            // Leaderboard button
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

                        // Attack alert
                        if let alert = attackAlert {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill").foregroundColor(Neon.red)
                                    .shadow(color: Neon.red, radius: 4)
                                Text(alert.uppercased())
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(1)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Neon.red.opacity(0.15))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Neon.red.opacity(0.7), lineWidth: 1))
                            .shadow(color: Neon.red.opacity(0.5), radius: 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Spacer()

                        // Stop button
                        Button(action: handleStop) {
                            HStack(spacing: 10) {
                                if isSaving {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                    Text("SYNCING...")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white).tracking(2)
                                } else {
                                    Image(systemName: "stop.fill")
                                        .foregroundColor(.white)
                                    Text("[ TERMINATE RUN ]")
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
                }
                .transition(.opacity)
                .onAppear {
                    if !locationManager.isTracking {
                        locationManager.startTracking()
                        realtimeManager.connect()
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

    private var hudDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 24)
            .padding(.horizontal, 2)
    }

    var speedColor: Color {
        switch locationManager.currentSpeed {
        case 0..<6:  return .white
        case 6..<10: return Neon.green
        case 10..<14:return Neon.orange
        default:     return Neon.red
        }
    }

    func checkAttacks() {
        let newIds = detectAttacks(myCoords: locationManager.routeCoordinates,
                                   otherRuns: realtimeManager.otherRuns.filter { $0.player_name != savedName })
        for id in newIds {
            if !attackedIds.contains(id) {
                attackedIds.insert(id); attackedCount += 1
                if let run = realtimeManager.otherRuns.first(where: { $0.id == id }) {
                    attackAlert = "ATTACKING ZONE: \(run.player_name)"
                    showAttackFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAttackFlash = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { attackAlert = nil }
                    let content = UNMutableNotificationContent()
                    content.title = "⚔ ATTACK"
                    content.body = "Capturing territory of \(run.player_name)"
                    content.sound = .default
                    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
                }
            }
        }
    }

    func handleStop() {
        locationManager.stopTracking(); isSaving = true
        Task {
            if !attackedIds.isEmpty { await SupabaseService.shared.deactivateRuns(ids: Array(attackedIds)) }
            await SupabaseService.shared.saveRun(playerName: savedName, coordinates: locationManager.routeCoordinates, color: savedColor)
            await SupabaseService.shared.upsertPlayer(name: savedName, distance: locationManager.distanceMeters, area: locationManager.conqueredArea, attacks: attackedCount)
            await MainActor.run { isSaving = false; withAnimation { showResults = true } }
        }
    }
}
