//
//  ChatView.swift
//  AICampaignConsultant
//

import SwiftUI

struct ChatView: View {
    let profile: CandidateProfile
    var auth: AuthViewModel
    var seedPrompt: String? = nil
    var onSeedConsumed: (() -> Void)? = nil

    private var currentSession: SupabaseSession? {
        if case let .ready(session, _, _) = auth.phase { return session }
        return nil
    }

    @State private var messages: [ChatMessage] = []
    @State private var messageMeta: [UUID: MessageMeta] = [:]
    @State private var input: String = ""
    @State private var isSending: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = "Check your network and try again."
    @State private var hasSentFirstMessage: Bool = false
    @State private var onlinePulse: Bool = false
    @State private var saveTarget: ChatMessage? = nil
    @State private var streamingId: UUID? = nil
    @State private var streamTask: Task<Void, Never>? = nil
    @State private var webSearchEnabled: Bool = false
    @State private var researchEnabled: Bool = false
    @State private var voterDataEnabled: Bool = false

    @FocusState private var inputFocused: Bool

    struct MessageMeta {
        var isCompliance: Bool = false
        var usedWebSearch: Bool = false
        var usedResearch: Bool = false
        var usedVoterData: Bool = false
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                badgeStrip
                Divider().background(Theme.goldFaint).frame(height: 1)
                conversationArea
                inputBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            seedWelcome()
            consumePendingSeed()
        }
        .onChange(of: seedPrompt) { _, _ in consumePendingSeed() }
        .alert("Chat unavailable", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(item: $saveTarget) { msg in
            SaveToLibrarySheet(
                initialBody: msg.content,
                onClose: { saveTarget = nil },
                onSaved: { _ in saveTarget = nil }
            )
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            LogoView(size: 36, glow: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("COLOSSUS CAMPAIGN OS")
                    .font(Theme.sans(12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.textPrimary)
                Text("by Colossus Strategies & Consulting")
                    .font(Theme.serif(11, weight: .regular))
                    .italic()
                    .foregroundStyle(Theme.gold)
            }
            Spacer()
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(Theme.online.opacity(0.35))
                        .frame(width: 14, height: 14)
                        .scaleEffect(onlinePulse ? 1.4 : 1.0)
                        .opacity(onlinePulse ? 0 : 1)
                    Circle().fill(Theme.online).frame(width: 8, height: 8)
                }
                Text("Online")
                    .font(Theme.sans(11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    onlinePulse = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.gold.opacity(0.45)).frame(height: 1)
        }
    }

    private var badgeStrip: some View {
        HStack {
            RaceContextBadge(profile: profile)
            Spacer()
            Text(profile.firstName)
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface.opacity(0.6))
    }

    // MARK: Conversation

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { msg in
                        VStack(alignment: .leading, spacing: 10) {
                            MessageBubbleView(message: msg)
                                .id(msg.id)

                            if msg.role == .assistant, messageMeta[msg.id]?.isCompliance == true {
                                ComplianceDisclaimerCard(
                                    jurisdictionContext: ComplianceClassifier.jurisdictionContext(for: profile),
                                    verifyWith: ComplianceClassifier.verifyWith(for: profile),
                                    severity: .informational
                                )
                                .padding(.leading, 42)
                                .padding(.trailing, 8)
                            }

                            if msg.role == .assistant {
                                actionRow(for: msg)
                            }
                        }
                    }

                    if !hasSentFirstMessage, !messages.isEmpty, !isSending {
                        QuickActionsGrid { action in
                            send(text: action.prompt)
                        }
                        .padding(.top, 6)
                        .transition(.opacity)
                    }

                    if isSending, streamingId == nil {
                        HStack(alignment: .top, spacing: 10) {
                            LogoView(size: 32, glow: false)
                            TypingIndicatorView()
                            Spacer(minLength: 32)
                        }
                        .id("typing")
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: messages.count) { _, _ in scroll(to: proxy) }
            .onChange(of: isSending) { _, _ in scroll(to: proxy) }
        }
        .background(Theme.bg)
    }

    private func actionRow(for msg: ChatMessage) -> some View {
        HStack(spacing: 14) {
            Spacer().frame(width: 32)
            Button {
                Haptics.tap()
                UIPasteboard.general.string = msg.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                saveTarget = msg
            } label: {
                Label("Save to Library", systemImage: "bookmark.fill")
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func scroll(to proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: Input

    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Ask your consultant…")
                            .font(Theme.sans(15))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $input, axis: .vertical)
                        .font(Theme.sans(15))
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .lineLimit(1...5)
                        .focused($inputFocused)
                }
                .background(Theme.inputBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Theme.goldFaint, lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 22))

                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        voterDataEnabled.toggle()
                        if voterDataEnabled { webSearchEnabled = false; researchEnabled = false }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voterDataEnabled
                                  ? LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Theme.inputBg, Theme.inputBg],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(voterDataEnabled ? Theme.gold : Theme.goldFaint, lineWidth: 1)
                            )
                        Image(systemName: "map.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(voterDataEnabled ? Theme.bg : Theme.goldDim)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .accessibilityLabel(voterDataEnabled ? "District data on" : "District data off")

                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        researchEnabled.toggle()
                        if researchEnabled { webSearchEnabled = false; voterDataEnabled = false }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(researchEnabled
                                  ? LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Theme.inputBg, Theme.inputBg],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(researchEnabled ? Theme.gold : Theme.goldFaint, lineWidth: 1)
                            )
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(researchEnabled ? Theme.bg : Theme.goldDim)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .accessibilityLabel(researchEnabled ? "FEC and Ballotpedia research on" : "FEC and Ballotpedia research off")

                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        webSearchEnabled.toggle()
                        if webSearchEnabled { researchEnabled = false; voterDataEnabled = false }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(webSearchEnabled
                                  ? LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Theme.inputBg, Theme.inputBg],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(webSearchEnabled ? Theme.gold : Theme.goldFaint, lineWidth: 1)
                            )
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(webSearchEnabled ? Theme.bg : Theme.goldDim)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                .accessibilityLabel(webSearchEnabled ? "Web search on" : "Web search off")

                Button {
                    if isSending {
                        cancelStream()
                    } else {
                        submitTapped()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(buttonActive
                                  ? LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                  : LinearGradient(colors: [Theme.goldDim.opacity(0.35), Theme.goldDim.opacity(0.35)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .shadow(color: buttonActive ? Theme.gold.opacity(0.4) : .clear, radius: 10, y: 3)

                        if isSending {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.bg)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.bg)
                                .offset(x: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!buttonActive)
                .animation(.easeInOut(duration: 0.15), value: isSending)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Text(stripLabel)
                .font(Theme.sans(9, weight: .bold))
                .tracking(3.2)
                .foregroundStyle((webSearchEnabled || researchEnabled || voterDataEnabled) ? Theme.gold : Theme.goldDim)
                .padding(.bottom, 6)
                .animation(.easeInOut(duration: 0.2), value: webSearchEnabled)
                .animation(.easeInOut(duration: 0.2), value: researchEnabled)
                .animation(.easeInOut(duration: 0.2), value: voterDataEnabled)
        }
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.gold.opacity(0.45)).frame(height: 1)
        }
    }

    private var stripLabel: String {
        if voterDataEnabled { return "DISTRICT DATA · LIVE VOTER FILE" }
        if researchEnabled { return "RESEARCH · FEC + BALLOTPEDIA" }
        if webSearchEnabled { return "WEB SEARCH ON · LIVE SOURCES" }
        return "EDUCATE · EMPOWER · WIN"
    }

    private var canSend: Bool {
        !isSending && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var buttonActive: Bool {
        isSending || canSend
    }

    private func cancelStream() {
        Haptics.tap()
        streamTask?.cancel()
    }

    private func submitTapped() {
        guard canSend else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        Haptics.tap()
        send(text: text)
    }

    // MARK: AI

    private func seedWelcome() {
        guard messages.isEmpty else { return }
        let welcome = """
        Welcome, \(profile.firstName)! I'm Colossus Campaign OS — your AI campaign consultant from Colossus Strategies & Consulting.

        I'm dialed in on your \(profile.raceType.label) race for \(profile.office.isEmpty ? profile.raceType.label : profile.office) in \(profile.location.isEmpty ? profile.state : profile.location). Every piece of advice I give you will be tailored to your specific race level, budget, and environment.

        What would you like to work on first?
        """
        messages.append(.init(role: .assistant, content: welcome))
    }

    private func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You're offline. Check your Wi-Fi or cellular connection and try again."
            case .timedOut:
                return "The request timed out. Try again in a moment."
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Couldn't reach the AI server. Try again shortly."
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        if let aiErr = error as? AIServiceError {
            switch aiErr {
            case .missingConfig:
                return "Chat isn't configured. Please reinstall or update the app."
            case .http(let code):
                if code == 401 || code == 403 {
                    return "Authorization failed (\(code)). Please sign out and sign back in."
                }
                if code == 402 {
                    return "Your AI usage limit was reached (402). Try again later or contact support."
                }
                if code == 429 {
                    return "Rate limit reached (429). Wait a minute and try again."
                }
                if code >= 500 {
                    return "AI server error (\(code)). Please try again shortly."
                }
                return "AI request failed with status \(code)."
            case .decoding:
                return "Couldn't read the AI response. Please try again."
            case .empty:
                return "The AI returned an empty response. Please try again."
            }
        }
        return error.localizedDescription
    }

    private func consumePendingSeed() {
        guard let seed = seedPrompt, !seed.isEmpty else { return }
        // Defer one tick so the welcome message lands first if this is a cold start.
        DispatchQueue.main.async {
            send(text: seed)
            onSeedConsumed?()
        }
    }

    private func send(text: String) {
        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        hasSentFirstMessage = true
        isSending = true

        let history = messages
        let prompt = AIService.systemPrompt(for: profile)
        let isComplianceQuestion = ComplianceClassifier.isCompliance(text)
        let useWebSearch = webSearchEnabled
        let useResearch = researchEnabled
        let useVoterData = voterDataEnabled

        if useVoterData, let session = currentSession {
            streamTask = Task {
                var failure: Error? = nil
                var answer = ""
                do {
                    answer = try await AIService.sendWithVoterTools(
                        history: history,
                        systemPrompt: prompt,
                        session: session
                    )
                } catch is CancellationError {
                } catch {
                    failure = error
                }
                await MainActor.run {
                    if let failure {
                        errorMessage = describe(failure)
                        showError = true
                    } else if !answer.isEmpty {
                        let msg = ChatMessage(role: .assistant, content: answer)
                        messages.append(msg)
                        messageMeta[msg.id] = MessageMeta(
                            isCompliance: isComplianceQuestion,
                            usedVoterData: true
                        )
                    }
                    streamingId = nil
                    isSending = false
                    streamTask = nil
                }
            }
            return
        }

        if useWebSearch || useResearch {
            streamTask = Task {
                var failure: Error? = nil
                var answer = ""
                do {
                    if useResearch {
                        answer = try await AIService.sendWithWebSearch(
                            history: history,
                            systemPrompt: prompt,
                            maxSearches: 6,
                            allowedDomains: [
                                "fec.gov",
                                "www.fec.gov",
                                "api.open.fec.gov",
                                "docquery.fec.gov",
                                "ballotpedia.org"
                            ],
                            researchMode: true
                        )
                    } else {
                        answer = try await AIService.sendWithWebSearch(history: history, systemPrompt: prompt)
                    }
                } catch is CancellationError {
                    // user-initiated stop
                } catch {
                    failure = error
                }
                await MainActor.run {
                    if let failure {
                        errorMessage = describe(failure)
                        showError = true
                    } else if !answer.isEmpty {
                        let msg = ChatMessage(role: .assistant, content: answer)
                        let isCompliance = isComplianceQuestion || ComplianceClassifier.isCompliance(answer)
                        messages.append(msg)
                        messageMeta[msg.id] = MessageMeta(
                            isCompliance: isCompliance,
                            usedWebSearch: useWebSearch,
                            usedResearch: useResearch
                        )
                    }
                    streamingId = nil
                    isSending = false
                    streamTask = nil
                }
            }
            return
        }

        streamTask = Task {
            var assistantId: UUID? = nil
            var buffer = ""
            var failure: Error? = nil
            do {
                for try await piece in AIService.stream(history: history, systemPrompt: prompt) {
                    try Task.checkCancellation()
                    buffer += piece
                    await MainActor.run {
                        if let id = assistantId,
                           let idx = messages.firstIndex(where: { $0.id == id }) {
                            messages[idx].content = buffer
                        } else {
                            let msg = ChatMessage(role: .assistant, content: buffer)
                            assistantId = msg.id
                            streamingId = msg.id
                            messages.append(msg)
                        }
                    }
                }
            } catch is CancellationError {
                // user-initiated stop — keep partial text
            } catch {
                failure = error
            }
            await MainActor.run {
                if let failure {
                    if let id = assistantId,
                       let idx = messages.firstIndex(where: { $0.id == id }),
                       messages[idx].content.isEmpty {
                        messages.remove(at: idx)
                    }
                    errorMessage = describe(failure)
                    showError = true
                } else if let id = assistantId, !buffer.isEmpty {
                    let isCompliance = isComplianceQuestion || ComplianceClassifier.isCompliance(buffer)
                    messageMeta[id] = MessageMeta(isCompliance: isCompliance)
                } else if let id = assistantId,
                          let idx = messages.firstIndex(where: { $0.id == id }),
                          messages[idx].content.isEmpty {
                    messages.remove(at: idx)
                }
                streamingId = nil
                isSending = false
                streamTask = nil
            }
        }
    }
}
