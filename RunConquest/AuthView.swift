import SwiftUI

// MARK: - Auth View

struct AuthView: View {
    @AppStorage("playerName")  private var savedName:  String = ""
    @AppStorage("playerColor") private var savedColor: String = "orange"
    @Environment(AppLanguage.self) private var lang

    @State private var mode: AuthMode = .login
    @State private var email    = ""
    @State private var password = ""
    @State private var callsign = ""
    @State private var isLoading         = false
    @State private var errorMsg: String? = nil
    @State private var needsConfirmation = false

    enum AuthMode { case login, register }

    var accent: Color { mode == .login ? Neon.cyan : Neon.magenta }

    var canSubmit: Bool {
        let emailOk    = email.contains("@") && email.contains(".")
        let passwordOk = password.count >= 6
        return mode == .register
            ? emailOk && passwordOk && isValidCallsign
            : emailOk && passwordOk
    }

    var isValidCallsign: Bool {
        let t = callsign.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3, t.count <= 20 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return t.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 6) {
                        NeonLabel(
                            text: lang.t("// SYSTEM ACCESS //", "// ДОСТУП К СИСТЕМЕ //"),
                            color: accent
                        )
                        Text(mode == .login
                             ? lang.t("SIGN IN", "ВХОД")
                             : lang.t("REGISTER", "РЕГИСТРАЦИЯ"))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(.white).tracking(4)
                            .shadow(color: accent, radius: 10)
                        NeonDivider(color: accent).padding(.horizontal, 40)
                    }
                    .padding(.top, 16)

                    // Mode toggle
                    HStack(spacing: 0) {
                        modeBtn(.login,    title: lang.t("SIGN IN",   "ВХОД"))
                        modeBtn(.register, title: lang.t("REGISTER",  "РЕГИСТРАЦИЯ"))
                    }
                    .padding(.horizontal)

                    // Fields
                    VStack(spacing: 12) {
                        if mode == .register {
                            authField(
                                icon: "person.fill",
                                placeholder: lang.t("CALLSIGN", "ПОЗЫВНОЙ"),
                                text: $callsign,
                                isSecure: false
                            )
                        }
                        authField(
                            icon: "envelope.fill",
                            placeholder: "EMAIL",
                            text: $email,
                            isSecure: false
                        )
                        authField(
                            icon: "lock.fill",
                            placeholder: lang.t("PASSWORD (min 6)", "ПАРОЛЬ (мин. 6 симв.)"),
                            text: $password,
                            isSecure: true
                        )
                    }
                    .padding(.horizontal)

                    // Error
                    if let err = errorMsg {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(err)
                                .font(.system(size: 11, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundColor(Neon.red)
                        .padding(.horizontal)
                    }

                    // Email confirmation notice
                    if needsConfirmation {
                        VStack(spacing: 8) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Neon.cyan)
                                .shadow(color: Neon.cyan.opacity(0.5), radius: 8)
                            Text(lang.t("CHECK YOUR EMAIL", "ПРОВЕРЬ ПОЧТУ"))
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.white).tracking(2)
                            Text(lang.t(
                                "Follow the confirmation link to activate your account, then sign in.",
                                "Перейди по ссылке в письме для активации, затем войди."
                            ))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        }
                        .padding()
                        .background(Neon.surface.opacity(0.4))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Neon.cyan.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal)
                    }

                    // Submit
                    Button(action: { Task { await submit() } }) {
                        Group {
                            if isLoading {
                                ProgressView().tint(Neon.bg)
                            } else {
                                Text(mode == .login
                                     ? lang.t("[ ACCESS GRANTED ▶ ]", "[ ВОЙТИ ▶ ]")
                                     : lang.t("[ DEPLOY AGENT ▶ ]",   "[ ЗАРЕГИСТРИРОВАТЬСЯ ▶ ]"))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .tracking(2)
                                    .foregroundColor(canSubmit ? Neon.bg : .gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSubmit && !isLoading ? accent : Color.gray.opacity(0.12))
                        .cornerRadius(4)
                        .shadow(color: canSubmit ? accent.opacity(0.5) : .clear, radius: 12)
                    }
                    .disabled(!canSubmit || isLoading)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: canSubmit)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func modeBtn(_ m: AuthMode, title: String) -> some View {
        let isActive = mode == m
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = m
                errorMsg = nil
                needsConfirmation = false
            }
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(isActive ? Neon.bg : .gray.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? accent : Neon.surface.opacity(0.3))
        }
        .cornerRadius(4)
    }

    @ViewBuilder
    private func authField(icon: String, placeholder: String,
                           text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(accent.opacity(0.7))
                .frame(width: 18)
            if isSecure {
                SecureField(
                    "",
                    text: text,
                    prompt: Text(placeholder)
                        .foregroundColor(.gray.opacity(0.3))
                        .font(.system(size: 13, design: .monospaced))
                )
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .accentColor(accent)
            } else {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholder)
                        .foregroundColor(.gray.opacity(0.3))
                        .font(.system(size: 13, design: .monospaced))
                )
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .accentColor(accent)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            }
        }
        .padding(14)
        .background(Neon.surface)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(accent.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func submit() async {
        errorMsg = nil
        needsConfirmation = false
        isLoading = true
        defer { isLoading = false }
        mode == .login ? await login() : await register()
    }

    private func login() async {
        let trimEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        let result = await SupabaseService.shared.signIn(email: trimEmail, password: password)
        switch result {
        case .success(let user):
            let lookupEmail = user.email ?? trimEmail
            if let player = await SupabaseService.shared.fetchPlayerByEmail(lookupEmail) {
                savedName = player.name
            } else {
                errorMsg = lang.t(
                    "No profile found. Please register.",
                    "Профиль не найден. Пожалуйста, зарегистрируйся."
                )
            }
        case .failure(let err):
            errorMsg = err.message
        }
    }

    private func register() async {
        let trimCallsign = callsign.trimmingCharacters(in: .whitespaces)
        let trimEmail    = email.lowercased().trimmingCharacters(in: .whitespaces)

        // Проверяем занят ли позывной
        if await SupabaseService.shared.fetchPlayer(name: trimCallsign) != nil {
            errorMsg = lang.t("Callsign already taken", "Позывной уже занят")
            return
        }

        let result = await SupabaseService.shared.signUp(email: trimEmail, password: password)
        switch result {
        case .success(let (_, needsConfirm)):
            await SupabaseService.shared.createPlayerProfile(
                name: trimCallsign, email: trimEmail, color: savedColor
            )
            if needsConfirm {
                needsConfirmation = true
            } else {
                savedName = trimCallsign
            }
        case .failure(let err):
            errorMsg = err.message
        }
    }
}
