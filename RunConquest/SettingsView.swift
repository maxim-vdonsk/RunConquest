import SwiftUI
import UserNotifications

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("playerName") private var playerName: String = ""
    @AppStorage("playerColor") private var playerColor: String = "orange"
    @AppStorage("useMetric") private var useMetric: Bool = true
    @AppStorage("showHeartRate") private var showHeartRate: Bool = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var notificationsEnabled = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Neon.cyan)
                            .frame(width: 36, height: 36)
                            .background(Neon.surface).cornerRadius(4)
                    }
                    Spacer()
                    Text(lang.t("SETTINGS", "НАСТРОЙКИ"))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(4)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal).padding(.top, 20).padding(.bottom, 16)

                NeonDivider().padding(.horizontal, 20).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Language
                        settingsSection(title: lang.t("LANGUAGE", "ЯЗЫК"), icon: "globe") {
                            VStack(spacing: 8) {
                                languageButton(code: "ru", label: "РУССКИЙ", flag: "🇷🇺")
                                languageButton(code: "en", label: "ENGLISH", flag: "🇺🇸")
                            }
                        }

                        // Player color
                        settingsSection(title: lang.t("PLAYER COLOR", "ЦВЕТ ИГРОКА"), icon: "paintpalette") {
                            colorPicker
                        }

                        // Units
                        settingsSection(title: lang.t("UNITS", "ЕДИНИЦЫ"), icon: "ruler") {
                            HStack(spacing: 8) {
                                unitButton(isMetric: true,  label: lang.t("KM / M²", "КМ / М²"))
                                unitButton(isMetric: false, label: lang.t("MILES / ACRES", "МИЛИ / АКРЫ"))
                            }
                        }

                        // HUD options
                        settingsSection(title: lang.t("HUD DISPLAY", "HUD ДИСПЛЕЙ"), icon: "speedometer") {
                            VStack(spacing: 10) {
                                settingsToggle(
                                    title: lang.t("Heart Rate", "Пульс"),
                                    subtitle: lang.t("Show BPM in run HUD", "Показывать пульс во время забега"),
                                    icon: "heart.fill",
                                    iconColor: Neon.red,
                                    isOn: $showHeartRate
                                )
                            }
                        }

                        // Notifications
                        settingsSection(title: lang.t("NOTIFICATIONS", "УВЕДОМЛЕНИЯ"), icon: "bell.fill") {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Neon.orange.opacity(0.12)).frame(width: 32, height: 32)
                                    Image(systemName: "bell.fill").font(.system(size: 13))
                                        .foregroundColor(Neon.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.t("Push Notifications", "Push-уведомления"))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Text(notificationsEnabled
                                         ? lang.t("Enabled", "Включены")
                                         : lang.t("Tap to enable in Settings", "Включить в настройках iOS"))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(notificationsEnabled ? Neon.green : .gray.opacity(0.5))
                                }
                                Spacer()
                                if notificationsEnabled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Neon.green)
                                } else {
                                    Button(action: openNotificationSettings) {
                                        Text(lang.t("OPEN", "ОТКРЫТЬ"))
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(Neon.orange).tracking(1)
                                            .frame(width: 60, height: 26)
                                            .background(Neon.orange.opacity(0.1))
                                            .cornerRadius(3)
                                            .overlay(RoundedRectangle(cornerRadius: 3)
                                                .stroke(Neon.orange.opacity(0.3), lineWidth: 1))
                                    }
                                }
                            }
                            .padding(12)
                            .background(Neon.surface.opacity(0.4)).cornerRadius(6)
                        }

                        // Privacy
                        settingsSection(title: lang.t("PRIVACY", "КОНФИДЕНЦИАЛЬНОСТЬ"), icon: "lock.fill") {
                            VStack(spacing: 8) {
                                infoRow(
                                    icon: "location.fill", color: Neon.cyan,
                                    title: lang.t("Location", "Геолокация"),
                                    value: lang.t("Used while running", "Используется при беге")
                                )
                                infoRow(
                                    icon: "heart.fill", color: Neon.red,
                                    title: lang.t("Health Data", "Данные здоровья"),
                                    value: lang.t("Heart rate & calories", "Пульс и калории")
                                )
                                infoRow(
                                    icon: "icloud.fill", color: Neon.magenta,
                                    title: lang.t("Cloud Sync", "Синхронизация"),
                                    value: lang.t("Runs saved securely", "Забеги сохраняются")
                                )
                            }
                        }

                        // About
                        settingsSection(title: lang.t("ABOUT", "О ПРИЛОЖЕНИИ"), icon: "info.circle") {
                            VStack(spacing: 8) {
                                infoRow(icon: "app.badge", color: Neon.cyan,
                                        title: "RunConquest",
                                        value: "v1.0.0")
                                infoRow(icon: "building.2", color: .gray,
                                        title: lang.t("Built with", "Создано с"),
                                        value: "SwiftUI + Supabase")
                            }
                        }

                        // Danger zone
                        settingsSection(title: lang.t("DANGER ZONE", "ОПАСНАЯ ЗОНА"), icon: "exclamationmark.triangle.fill") {
                            Button(action: { showResetConfirm = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(lang.t("SHOW ONBOARDING AGAIN", "ПОКАЗАТЬ ОНБОРДИНГ"))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                                }
                                .foregroundColor(Neon.red)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Neon.red.opacity(0.07))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .stroke(Neon.red.opacity(0.25), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 40)
                }
            }
        }
        .onAppear { checkNotificationStatus() }
        .confirmationDialog(
            lang.t("Reset onboarding?", "Сбросить онбординг?"),
            isPresented: $showResetConfirm
        ) {
            Button(lang.t("Yes, show again", "Да, показать снова"), role: .destructive) {
                hasSeenOnboarding = false
            }
            Button(lang.t("Cancel", "Отмена"), role: .cancel) {}
        }
    }

    // MARK: - Sub-views

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(Neon.cyan.opacity(0.7))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Neon.cyan.opacity(0.7)).tracking(3)
            }
            content()
        }
    }

    private func languageButton(code: String, label: String, flag: String) -> some View {
        let isSelected = lang.code == code
        return Button(action: { lang.set(code) }) {
            HStack(spacing: 10) {
                Text(flag).font(.system(size: 18))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? Neon.cyan : .white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Neon.cyan)
                }
            }
            .padding(12)
            .background(isSelected ? Neon.cyan.opacity(0.08) : Neon.surface.opacity(0.4))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Neon.cyan.opacity(0.4) : Color.clear, lineWidth: 1))
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 10) {
            ForEach(["orange", "blue", "green", "red", "purple"], id: \.self) { colorName in
                let col = Neon.colorMap[colorName] ?? Neon.cyan
                let isSelected = playerColor == colorName
                Button(action: { playerColor = colorName }) {
                    ZStack {
                        Circle().fill(col.opacity(0.2)).frame(width: 40, height: 40)
                        if isSelected {
                            Circle().stroke(col, lineWidth: 2).frame(width: 40, height: 40)
                            Circle().fill(col).frame(width: 18, height: 18)
                        } else {
                            Circle().fill(col.opacity(0.6)).frame(width: 14, height: 14)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    private func unitButton(isMetric: Bool, label: String) -> some View {
        let isSelected = useMetric == isMetric
        return Button(action: { useMetric = isMetric }) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? Neon.cyan : .gray.opacity(0.5))
                .tracking(1)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(isSelected ? Neon.cyan.opacity(0.08) : Neon.surface.opacity(0.3))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Neon.cyan.opacity(0.4) : Color.clear, lineWidth: 1))
        }
    }

    private func settingsToggle(title: String, subtitle: String, icon: String, iconColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray.opacity(0.5))
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
                .tint(Neon.cyan)
        }
        .padding(12)
        .background(Neon.surface.opacity(0.4)).cornerRadius(6)
    }

    private func infoRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 28, height: 28)
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
            }
            Text(title).font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
            Spacer()
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Neon.surface.opacity(0.3)).cornerRadius(4)
    }

    // MARK: - Notifications

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
