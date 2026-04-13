import SwiftUI

// MARK: - Squads View

struct SquadsView: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @State private var mySquad: Squad? = nil
    @State private var members: [SquadMember] = []
    @State private var allSquads: [Squad] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var showJoin = false

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    NeonLabel(text: lang.t("// UNITS //", "// ОТРЯДЫ //"))
                    Text(lang.t("SQUADS", "ОТРЯДЫ"))
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(6)
                        .shadow(color: Neon.magenta, radius: 8)
                    NeonDivider(color: Neon.magenta).padding(.horizontal, 40)
                }
                .padding(.top, 24).padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView().tint(Neon.magenta)
                    Spacer()
                } else if let squad = mySquad {
                    mySquadView(squad: squad)
                } else {
                    noSquadView
                }
            }
        }
        .sheet(isPresented: $showCreate, onDismiss: { Task { await loadData() } }) {
            CreateSquadSheet(playerName: playerName)
        }
        .sheet(isPresented: $showJoin, onDismiss: { Task { await loadData() } }) {
            JoinSquadSheet(playerName: playerName)
        }
        .task { await loadData() }
    }

    // MARK: - My Squad View

    private func mySquadView(squad: Squad) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Squad card
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Neon.magenta.opacity(0.12)).frame(width: 72, height: 72)
                        Circle().stroke(Neon.magenta.opacity(0.5), lineWidth: 2).frame(width: 60, height: 60)
                        Text(String(squad.name.prefix(2)).uppercased())
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(Neon.magenta)
                    }
                    Text(squad.name.uppercased())
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Image(systemName: "number.square").font(.system(size: 11))
                            .foregroundColor(Neon.cyan.opacity(0.6))
                        Text(squad.invite_code.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Neon.cyan).tracking(3)
                        Text(lang.t("— share to invite", "— поделись для приглашения"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Neon.surface.opacity(0.6))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Neon.magenta.opacity(0.2), lineWidth: 1))

                // Stats row
                HStack(spacing: 0) {
                    squadStat(icon: "person.3.fill", value: "\(squad.member_count)", label: lang.t("MEMBERS", "УЧАСТНИКИ"))
                    Rectangle().fill(Color.white.opacity(0.05)).frame(width: 1, height: 36)
                    squadStat(icon: "map.fill", value: String(format: "%.0f", squad.total_area), label: "M²")
                    Rectangle().fill(Color.white.opacity(0.05)).frame(width: 1, height: 36)
                    squadStat(icon: "figure.run", value: "\(squad.total_runs)", label: lang.t("RUNS", "ЗАБЕГОВ"))
                }
                .padding(14)
                .background(Neon.surface.opacity(0.4))
                .cornerRadius(6)

                // Members section
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("MEMBERS", "УЧАСТНИКИ"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.magenta.opacity(0.7)).tracking(3)
                        .padding(.horizontal, 4)

                    ForEach(members, id: \.player_name) { member in
                        SquadMemberRow(member: member, isMe: member.player_name == playerName)
                    }
                }

                // Leave button
                Button(action: { Task { await leaveSquad() } }) {
                    Text(lang.t("LEAVE SQUAD", "ПОКИНУТЬ ОТРЯД"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.red).tracking(2)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Neon.red.opacity(0.07))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Neon.red.opacity(0.25), lineWidth: 1))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
    }

    // MARK: - No Squad View

    private var noSquadView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "shield.slash").font(.system(size: 48))
                    .foregroundColor(Neon.magenta.opacity(0.3))
                Text(lang.t("NO SQUAD", "НЕТ ОТРЯДА"))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white).tracking(4)
                Text(lang.t("Join a squad or create your own", "Вступи в отряд или создай свой"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: { showCreate = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(lang.t("CREATE SQUAD", "СОЗДАТЬ ОТРЯД"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(2)
                    }
                    .foregroundColor(Neon.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Neon.magenta)
                    .cornerRadius(6)
                    .shadow(color: Neon.magenta.opacity(0.4), radius: 10)
                }
                Button(action: { showJoin = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                        Text(lang.t("JOIN BY CODE", "ВСТУПИТЬ ПО КОДУ"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(2)
                    }
                    .foregroundColor(Neon.magenta)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Neon.magenta.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Neon.magenta.opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 40)

            // Available squads
            if !allSquads.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    NeonDivider(color: Neon.magenta.opacity(0.3)).padding(.horizontal, 40)
                    Text(lang.t("ACTIVE SQUADS", "АКТИВНЫЕ ОТРЯДЫ"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.magenta.opacity(0.6)).tracking(3)
                        .padding(.horizontal)
                    ForEach(allSquads) { squad in
                        SquadListRow(squad: squad, onJoin: {
                            Task { await joinSquad(code: squad.code) }
                        })
                        .padding(.horizontal)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func squadStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(Neon.magenta.opacity(0.6))
            Text(value).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
            Text(label).font(.system(size: 7, design: .monospaced)).foregroundColor(.gray.opacity(0.4)).tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadData() async {
        isLoading = true
        async let s = SupabaseService.shared.fetchMySquad(playerName: playerName)
        async let a = SupabaseService.shared.fetchSquads()
        let (sq, all) = await (s, a)
        mySquad = sq
        allSquads = all.filter { $0.id != sq?.id }
        if let sq = sq {
            members = await SupabaseService.shared.fetchSquadMembers(squadId: sq.id ?? "")
        }
        isLoading = false
    }

    private func leaveSquad() async {
        await SupabaseService.shared.leaveSquad(playerName: playerName)
        await loadData()
    }

    private func joinSquad(code: String) async {
        await SupabaseService.shared.joinSquad(playerName: playerName, code: code)
        await loadData()
    }
}

// MARK: - Squad Member Row

struct SquadMemberRow: View {
    let member: SquadMember
    let isMe: Bool
    @Environment(AppLanguage.self) private var lang

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Neon.magenta.opacity(0.12)).frame(width: 32, height: 32)
                Text(String(member.player_name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(Neon.magenta)
            }
            Text(member.player_name.uppercased())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isMe ? Neon.magenta : .white)
            if isMe {
                Text(lang.t("YOU", "ВЫ"))
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(Neon.magenta.opacity(0.6))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Neon.magenta.opacity(0.1)).cornerRadius(2)
            }
            Spacer()
            if member.player_name == member.squad_name {
                // placeholder: squad creator indicator removed (no role field in model)
            }
        }
        .padding(10)
        .background(Neon.surface.opacity(0.4)).cornerRadius(4)
    }
}

// MARK: - Squad List Row

struct SquadListRow: View {
    let squad: Squad
    let onJoin: () -> Void
    @Environment(AppLanguage.self) private var lang

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Neon.magenta.opacity(0.12)).frame(width: 36, height: 36)
                Text(String(squad.name.prefix(2)).uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(Neon.magenta)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(squad.name.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white)
                Text("\(squad.member_count) \(lang.t("members", "участника"))")
                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray.opacity(0.4))
            }
            Spacer()
            Button(action: onJoin) {
                Text(lang.t("JOIN", "ВСТУПИТЬ"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Neon.magenta).tracking(1)
                    .frame(width: 64, height: 26)
                    .background(Neon.magenta.opacity(0.1))
                    .cornerRadius(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Neon.magenta.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(10)
        .background(Neon.surface.opacity(0.4)).cornerRadius(4)
    }
}

// MARK: - Create Squad Sheet

struct CreateSquadSheet: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var loading = false
    @State private var error: String? = nil

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 24) {
                HStack {
                    Text(lang.t("CREATE SQUAD", "СОЗДАТЬ ОТРЯД"))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(4)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.white)
                            .frame(width: 36, height: 36).background(.ultraThinMaterial).cornerRadius(4)
                    }
                }
                .padding(.horizontal).padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("SQUAD NAME", "НАЗВАНИЕ ОТРЯДА"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Neon.magenta.opacity(0.7)).tracking(3)
                    TextField(lang.t("Enter name...", "Введи название..."), text: $name)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white).autocorrectionDisabled()
                        .padding(12)
                        .background(Neon.surface)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Neon.magenta.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal)

                if let err = error {
                    Text(err).font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Neon.red).padding(.horizontal)
                }

                Button(action: createSquad) {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.black).scaleEffect(0.8) }
                        Text(lang.t("CREATE", "СОЗДАТЬ"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(2)
                    }
                    .foregroundColor(Neon.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(name.count >= 2 ? Neon.magenta : Neon.magenta.opacity(0.3))
                    .cornerRadius(6)
                }
                .disabled(name.count < 2 || loading)
                .padding(.horizontal)
                Spacer()
            }
        }
    }

    private func createSquad() {
        loading = true
        error = nil
        Task {
            let ok = await SupabaseService.shared.createSquad(name: name, leaderName: playerName)
            if ok {
                dismiss()
            } else {
                error = lang.t("Failed to create squad", "Не удалось создать отряд")
            }
            loading = false
        }
    }
}

// MARK: - Join Squad Sheet

struct JoinSquadSheet: View {
    let playerName: String
    @Environment(AppLanguage.self) private var lang
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var loading = false
    @State private var error: String? = nil

    var body: some View {
        ZStack {
            Neon.bg.ignoresSafeArea()
            GridBackground()

            VStack(spacing: 24) {
                HStack {
                    Text(lang.t("JOIN SQUAD", "ВСТУПИТЬ В ОТРЯД"))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white).tracking(4)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.white)
                            .frame(width: 36, height: 36).background(.ultraThinMaterial).cornerRadius(4)
                    }
                }
                .padding(.horizontal).padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("INVITE CODE", "КОД ПРИГЛАШЕНИЯ"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Neon.cyan.opacity(0.7)).tracking(3)
                    TextField(lang.t("Enter code...", "Введи код..."), text: $code)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(Neon.cyan).autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .padding(12)
                        .background(Neon.surface)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Neon.cyan.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal)

                if let err = error {
                    Text(err).font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Neon.red).padding(.horizontal)
                }

                Button(action: joinSquad) {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.black).scaleEffect(0.8) }
                        Text(lang.t("JOIN", "ВСТУПИТЬ"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(2)
                    }
                    .foregroundColor(Neon.bg)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(code.count >= 4 ? Neon.cyan : Neon.cyan.opacity(0.3))
                    .cornerRadius(6)
                }
                .disabled(code.count < 4 || loading)
                .padding(.horizontal)
                Spacer()
            }
        }
    }

    private func joinSquad() {
        loading = true
        error = nil
        Task {
            let ok = await SupabaseService.shared.joinSquad(playerName: playerName, code: code.uppercased())
            if ok {
                dismiss()
            } else {
                error = lang.t("Invalid code or squad full", "Неверный код или отряд переполнен")
            }
            loading = false
        }
    }
}
