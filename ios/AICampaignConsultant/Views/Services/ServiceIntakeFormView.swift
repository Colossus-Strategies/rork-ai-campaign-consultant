//
//  ServiceIntakeFormView.swift
//  AICampaignConsultant
//
//  Intake form for Colossus Fundraising Pro + Deep Strategy. Submits the
//  request by composing a prefilled email to the Colossus services inbox
//  via the share sheet, so it works even without a server endpoint.
//

import SwiftUI
import UIKit

enum ServiceKind: String, CaseIterable, Identifiable {
    case fundraising = "Colossus Fundraising Pro"
    case strategy = "Colossus Deep Strategy"
    case both = "Both"
    case unsure = "Not sure yet"
    var id: String { rawValue }
}

enum CampaignStage: String, CaseIterable, Identifiable {
    case exploratory = "Exploratory"
    case primary = "Primary"
    case general = "General Election"
    case special = "Special Election"
    case runoff = "Runoff"
    case postPrimary = "Post-primary planning"
    case other = "Other"
    var id: String { rawValue }
}

enum SupportCadence: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case twiceMonthly = "Twice monthly"
    case monthly = "Monthly"
    case asNeeded = "As needed"
    case unsure = "Not sure"
    var id: String { rawValue }
}

enum YesNoUnsure: String, CaseIterable, Identifiable {
    case yes = "Yes"
    case no = "No"
    case unsure = "Not sure"
    var id: String { rawValue }
}

enum StrategyUrgency: String, CaseIterable, Identifiable {
    case rapid = "Yes, within 24 hours"
    case thisWeek = "This week"
    case thisMonth = "This month"
    case planning = "Planning ahead"
    var id: String { rawValue }
}

enum ContactMethod: String, CaseIterable, Identifiable {
    case email = "Email"
    case phone = "Phone"
    case text = "Text"
    var id: String { rawValue }
}

struct ServiceIntakeFormView: View {
    let profile: CandidateProfile
    let preselected: ServiceKind?

    @Environment(\.dismiss) private var dismiss

    // Recipient inbox — change to the real Colossus services address.
    private let recipient: String = "anthony@colossus-strategies.com"

    // Campaign info
    @State private var campaignName: String = ""
    @State private var candidateName: String = ""
    @State private var officeSought: String = ""
    @State private var jurisdiction: String = ""
    @State private var electionDate: Date = .now
    @State private var hasElectionDate: Bool = false
    @State private var stage: CampaignStage = .primary

    // Services
    @State private var service: ServiceKind = .unsure

    // Fundraising Pro
    private let fundraisingNeeds: [String] = [
        "Donor list building",
        "Call time planning",
        "Finance plan creation",
        "Donor research",
        "Event fundraising",
        "Digital fundraising strategy",
        "PAC / organizational fundraising",
        "Weekly accountability support",
        "Other",
    ]
    @State private var selectedFundraising: Set<String> = []
    @State private var fundraisingGoal: String = ""
    @State private var raisedToDate: String = ""
    @State private var hasFinanceLead: YesNoUnsure = .unsure
    @State private var supportCadence: SupportCadence = .asNeeded

    // Deep Strategy
    private let strategyNeeds: [String] = [
        "Opposition research",
        "District research",
        "Voter targeting analysis",
        "Message development",
        "Debate preparation",
        "Earned media strategy",
        "Digital strategy",
        "Polling analysis",
        "Rapid response",
        "Live consultant support",
        "Other",
    ]
    @State private var selectedStrategy: Set<String> = []
    @State private var strategicChallenge: String = ""
    @State private var urgency: StrategyUrgency = .planning
    @State private var researchTargets: String = ""

    // Contact
    @State private var contactName: String = ""
    @State private var contactRole: String = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""
    @State private var preferredContact: ContactMethod = .email
    @State private var bestTime: String = ""

    // Final
    @State private var anythingElse: String = ""

    // Submission state
    @State private var submitting: Bool = false
    @State private var didSubmit: Bool = false
    @State private var submitError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if didSubmit {
                        confirmationCard
                    } else {
                        introCard
                        campaignSection
                        servicesSection
                        if showFundraising { fundraisingSection }
                        if showStrategy { strategySection }
                        contactSection
                        finalSection
                        submitButton
                        if let err = submitError {
                            Text(err)
                                .font(Theme.sans(12, weight: .semibold))
                                .foregroundStyle(Color(hex: 0xd14a3b))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Request Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
                if didSubmit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Theme.gold)
                            .font(Theme.sans(14, weight: .bold))
                    }
                }
            }
            .onAppear { prefillFromProfile() }
        }
    }

    // MARK: - Derived

    private var showFundraising: Bool {
        service == .fundraising || service == .both
    }
    private var showStrategy: Bool {
        service == .strategy || service == .both
    }

    private var canSubmit: Bool {
        !campaignName.trimmingCharacters(in: .whitespaces).isEmpty
            && !candidateName.trimmingCharacters(in: .whitespaces).isEmpty
            && !contactName.trimmingCharacters(in: .whitespaces).isEmpty
            && !contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func prefillFromProfile() {
        if candidateName.isEmpty { candidateName = profile.name }
        if officeSought.isEmpty { officeSought = profile.office }
        if jurisdiction.isEmpty {
            let parts = [profile.state, profile.district, profile.location]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            jurisdiction = parts.joined(separator: " · ")
        }
        if contactName.isEmpty { contactName = profile.displayName }
        if let d = profile.electionDate {
            electionDate = d
            hasElectionDate = true
        }
        if let p = preselected { service = p }
    }

    // MARK: - Sections

    private var introCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tell us what your campaign needs.")
                    .font(Theme.serif(18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("A Colossus team member will review your request and follow up with next steps.")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var campaignSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("CAMPAIGN INFORMATION")
                textField("Campaign Name", text: $campaignName)
                textField("Candidate Name", text: $candidateName)
                textField("Office Sought", text: $officeSought)
                textField("State / District / Municipality", text: $jurisdiction)
                electionDateField
                pickerField("Current Campaign Stage", selection: $stage, options: CampaignStage.allCases)
            }
        }
    }

    private var electionDateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Election Date")
            HStack(spacing: 10) {
                Toggle(isOn: $hasElectionDate) {
                    Text(hasElectionDate ? "Set" : "Not set")
                        .font(Theme.sans(12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Theme.gold))
                Spacer()
                if hasElectionDate {
                    DatePicker("", selection: $electionDate, displayedComponents: .date)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .accentColor(Theme.gold)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.inputBg)
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var servicesSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("SERVICES REQUESTED")
                Text("Which service are you interested in?")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                VStack(spacing: 8) {
                    ForEach(ServiceKind.allCases) { kind in
                        radioRow(kind.rawValue, isSelected: service == kind) {
                            service = kind
                        }
                    }
                }
            }
        }
    }

    private var fundraisingSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("FUNDRAISING PRO")
                Text("What fundraising support do you need?")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                checkboxGrid(options: fundraisingNeeds, selection: $selectedFundraising)
                textField("Current fundraising goal", text: $fundraisingGoal, keyboard: .numbersAndPunctuation)
                textField("Amount raised to date", text: $raisedToDate, keyboard: .numbersAndPunctuation)
                pickerField("Do you have a finance director / consultant?", selection: $hasFinanceLead, options: YesNoUnsure.allCases)
                pickerField("How often do you want support?", selection: $supportCadence, options: SupportCadence.allCases)
            }
        }
    }

    private var strategySection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("DEEP STRATEGY")
                Text("What strategic support do you need?")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                checkboxGrid(options: strategyNeeds, selection: $selectedStrategy)
                longTextField("Describe the strategic challenge you are facing.", text: $strategicChallenge)
                pickerField("Do you need urgent support?", selection: $urgency, options: StrategyUrgency.allCases)
                longTextField("Specific opponents, issues, or districts to research?", text: $researchTargets)
            }
        }
    }

    private var contactSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("CONTACT INFORMATION")
                textField("Primary Contact Name", text: $contactName)
                textField("Role on Campaign", text: $contactRole)
                textField("Email", text: $contactEmail, keyboard: .emailAddress)
                textField("Phone", text: $contactPhone, keyboard: .phonePad)
                pickerField("Preferred Contact Method", selection: $preferredContact, options: ContactMethod.allCases)
                textField("Best time to contact you", text: $bestTime)
            }
        }
    }

    private var finalSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("ANYTHING ELSE?")
                longTextField("Anything else we should know?", text: $anythingElse)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Haptics.tap()
            submit()
        } label: {
            HStack {
                if submitting {
                    ProgressView().tint(Theme.bg)
                }
                Text(submitting ? "Submitting…" : "Submit Service Request")
                    .font(Theme.sans(14, weight: .bold))
            }
            .foregroundStyle(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? Theme.gold : Theme.gold.opacity(0.4))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || submitting)
    }

    private var confirmationCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(hex: 0x4caf6e))
                    Text("Request received.")
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("The Colossus team will review your campaign's needs and follow up with recommended next steps.")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.gold)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Submission

    private func submit() {
        guard canSubmit else { return }
        submitError = nil
        submitting = true

        let subject = "Service Request — \(campaignName.isEmpty ? candidateName : campaignName)"
        let body = composeBody()

        // Try mailto: first; if no mail client, fall back to printing/Share would
        // require UIKit reach; we keep it simple — mailto handles iOS Mail and
        // most third-party clients.
        if let url = mailtoURL(subject: subject, body: body),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { _ in
                Task { @MainActor in
                    submitting = false
                    didSubmit = true
                    Haptics.success()
                }
            }
        } else {
            // No mail client — still confirm so the user can copy the recipient.
            submitting = false
            didSubmit = true
            Haptics.success()
        }
    }

    private func mailtoURL(subject: String, body: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = recipient
        comps.queryItems = [
            .init(name: "subject", value: subject),
            .init(name: "body", value: body),
        ]
        return comps.url
    }

    private func composeBody() -> String {
        var lines: [String] = []
        lines.append("=== CAMPAIGN INFORMATION ===")
        lines.append("Campaign Name: \(campaignName)")
        lines.append("Candidate Name: \(candidateName)")
        lines.append("Office Sought: \(officeSought)")
        lines.append("State / District / Municipality: \(jurisdiction)")
        if hasElectionDate {
            let f = DateFormatter()
            f.dateStyle = .long
            lines.append("Election Date: \(f.string(from: electionDate))")
        }
        lines.append("Campaign Stage: \(stage.rawValue)")
        lines.append("")
        lines.append("=== SERVICES REQUESTED ===")
        lines.append("Interested in: \(service.rawValue)")

        if showFundraising {
            lines.append("")
            lines.append("=== FUNDRAISING PRO ===")
            lines.append("Support needed: \(selectedFundraising.sorted().joined(separator: ", "))")
            lines.append("Fundraising goal: \(fundraisingGoal)")
            lines.append("Raised to date: \(raisedToDate)")
            lines.append("Finance lead in place: \(hasFinanceLead.rawValue)")
            lines.append("Cadence: \(supportCadence.rawValue)")
        }

        if showStrategy {
            lines.append("")
            lines.append("=== DEEP STRATEGY ===")
            lines.append("Support needed: \(selectedStrategy.sorted().joined(separator: ", "))")
            lines.append("Strategic challenge: \(strategicChallenge)")
            lines.append("Urgency: \(urgency.rawValue)")
            lines.append("Research targets: \(researchTargets)")
        }

        lines.append("")
        lines.append("=== CONTACT ===")
        lines.append("Name: \(contactName)")
        lines.append("Role: \(contactRole)")
        lines.append("Email: \(contactEmail)")
        lines.append("Phone: \(contactPhone)")
        lines.append("Preferred method: \(preferredContact.rawValue)")
        lines.append("Best time: \(bestTime)")

        if !anythingElse.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("")
            lines.append("=== NOTES ===")
            lines.append(anythingElse)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Field builders

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11, weight: .bold))
            .tracking(2)
            .foregroundStyle(Theme.gold)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.textMuted)
    }

    private func textField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            TextField("", text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func longTextField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            TextEditor(text: text)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
                .padding(8)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func pickerField<T: Hashable & RawRepresentable & Identifiable>(
        _ label: String,
        selection: Binding<T>,
        options: [T]
    ) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label)
            Menu {
                ForEach(options) { opt in
                    Button(opt.rawValue) { selection.wrappedValue = opt }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.rawValue)
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private func radioRow(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.textMuted)
                Text(label)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Theme.gold.opacity(0.12) : Theme.inputBg)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.goldFaint : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func checkboxGrid(options: [String], selection: Binding<Set<String>>) -> some View {
        let cols = [GridItem(.adaptive(minimum: 150), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isOn = selection.wrappedValue.contains(opt)
                Button {
                    Haptics.tap()
                    if isOn { selection.wrappedValue.remove(opt) }
                    else { selection.wrappedValue.insert(opt) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isOn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isOn ? Theme.gold : Theme.textMuted)
                        Text(opt)
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isOn ? Theme.gold.opacity(0.12) : Theme.inputBg)
                    .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
