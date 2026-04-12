import SwiftUI
import UserNotifications

// MARK: - Animated HUD Stat

struct AnimatedHUDStat: View {
    let value: String
    let unit: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).monospacedDigit().foregroundColor(color)
            Text(unit).font(.caption2).foregroundColor(.secondary)
        }
        .frame(minWidth: 54)
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

                    if showAttackFlash {
                        Color.red.opacity(0.25).ignoresSafeArea()
                            .transition(.opacity).animation(.easeInOut(duration: 0.2), value: showAttackFlash)
                    }

                    VStack {
                        HStack(spacing: 10) {
                            Button(action: { showProfile = true }) {
                                ZStack {
                                    Circle().fill(Color.orange).frame(width: 42, height: 42)
                                        .shadow(color: .orange.opacity(0.5), radius: 8)
                                    Text(String(savedName.prefix(1)).uppercased())
                                        .font(.headline.bold()).foregroundColor(.white)
                                }
                            }

                            HStack(spacing: 0) {
                                AnimatedHUDStat(value: String(format: "%.2f", locationManager.distanceMeters / 1000), unit: "КМ", color: .white)
                                Divider().background(Color.white.opacity(0.2)).frame(height: 28)
                                AnimatedHUDStat(value: String(format: "%.0f", locationManager.currentSpeed), unit: "КМ/Ч", color: speedColor)
                                Divider().background(Color.white.opacity(0.2)).frame(height: 28)
                                AnimatedHUDStat(value: "\(points)", unit: "PTS", color: .orange)
                                if attackedCount > 0 {
                                    Divider().background(Color.white.opacity(0.2)).frame(height: 28)
                                    AnimatedHUDStat(value: "⚔️\(attackedCount)", unit: "АТАК", color: .red)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.ultraThinMaterial).cornerRadius(16)

                            Spacer()

                            Button(action: { showLeaderboard = true }) {
                                Image(systemName: "trophy.fill").foregroundColor(.orange)
                                    .frame(width: 42, height: 42)
                                    .background(.ultraThinMaterial).cornerRadius(21)
                                    .shadow(color: .orange.opacity(0.3), radius: 8)
                            }
                        }
                        .padding(.horizontal).padding(.top, 8)

                        if let alert = attackAlert {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                                Text(alert).font(.caption.bold()).foregroundColor(.white)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color.red.opacity(0.9)).cornerRadius(20)
                            .shadow(color: .red.opacity(0.5), radius: 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Spacer()

                        Button(action: handleStop) {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                    Text("СОХРАНЯЕМ...").bold()
                                } else {
                                    Image(systemName: "stop.fill")
                                    Text("СТОП").bold().tracking(2)
                                }
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).padding()
                            .background(Color.red).cornerRadius(16).padding(.horizontal)
                            .shadow(color: .red.opacity(pulseTracking ? 0.6 : 0.2), radius: pulseTracking ? 16 : 6)
                            .scaleEffect(pulseTracking ? 1.02 : 1.0)
                        }
                        .disabled(isSaving).padding(.bottom, 8)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
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

    var speedColor: Color {
        switch locationManager.currentSpeed {
        case 0..<6: return .white
        case 6..<10: return .green
        case 10..<14: return .orange
        default: return .red
        }
    }

    func checkAttacks() {
        let newIds = detectAttacks(myCoords: locationManager.routeCoordinates,
                                   otherRuns: realtimeManager.otherRuns.filter { $0.player_name != savedName })
        for id in newIds {
            if !attackedIds.contains(id) {
                attackedIds.insert(id); attackedCount += 1
                if let run = realtimeManager.otherRuns.first(where: { $0.id == id }) {
                    attackAlert = "Атакуешь зону \(run.player_name)!"
                    showAttackFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAttackFlash = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { attackAlert = nil }
                    let content = UNMutableNotificationContent()
                    content.title = "⚔️ Атака!"
                    content.body = "Ты захватываешь территорию \(run.player_name)!"
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
