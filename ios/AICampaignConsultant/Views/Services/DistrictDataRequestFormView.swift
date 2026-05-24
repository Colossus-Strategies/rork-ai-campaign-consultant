//
//  DistrictDataRequestFormView.swift
//  AICampaignConsultant
//
//  Intake form for the District Intelligence (included) service. Composes
//  a prefilled mailto so the Colossus team can fulfil the data request
//  manually while we figure out the in-app data surface.
//

import SwiftUI
import UIKit

struct DistrictDataRequestFormView: View {
    let profile: CandidateProfile

    @Environment(\.dismiss) private var dismiss

    private let recipient: String = "anthony@colossus-strategies.com"

    // Campaign info
    @State private var campaignName: String = ""
    @State private var candidateName: String = ""
    @State private var officeSought: String = ""
    @State private var stateField: String = ""
    @State private var districtField: String = ""
    @State private var locality: String = ""
    @State private var electionDate: Date = .now
    @State private var hasElectionDate: Bool = false

    // Data needs
    private let dataOptions: [String] = [
        "Voter file (active registrations)",
        "Party affiliation breakdown",
        "Turnout history",
        "Precinct-level results",
        "Demographic overlay",
        "Door-knocking walk lists",
        "Persuasion universe",
        "GOTV universe",
        "Absentee / early vote history",
        "Donor overlap analysis",
        "Custom segmentation",
    ]
    @State private var selectedData: Set<String> = []

    @State private var priority: DistrictPriority = .planning
    @State private var deliveryNotes: String = ""

    // Contact
    @State private var contactName: String = ""
    @State private var contactEmail: String = ""
    @State private var contactPhone: String = ""

    @State private var submitting: Bool = false
    @State private var didSubmit: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if didSubmit {
                        confirmation
                    } else {
                        intro
                        campaignSection
                        districtSection
                        dataSection
                        contactSection
                        submitButton
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Request District Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .onAppear { prefill() }
        }
    }

    private var canSubmit: Bool {
        !candidateName.trimmingCharacters(in: .whitespaces).isEmpty
            && !contactEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && (!stateField.trimmingCharacters(in: .whitespaces).isEmpty
                || !districtField.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func prefill() {
        if candidateName.isEmpty { candidateName = profile.name }
        if officeSought.isEmpty { officeSought = profile.office }
        if stateField.isEmpty { stateField = profile.state }
        if districtField.isEmpty { districtField = profile.district }
        if locality.isEmpty { locality = profile.location }
        if contactName.isEmpty { contactName = profile.displayName }
        if let d = profile.electionDate {
            electionDate = d
            hasElectionDate = true
        }
    }

    // MARK: - Sections

    private var intro: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    Text("INCLUDED WITH YOUR PLAN")
                        .font(Theme.sans(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Theme.gold)
                }
                Text("Tell us about your race.")
                    .font(Theme.serif(20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Our team pulls voter file, turnout history, and district analytics for your race and delivers it to you — usually within 2 business days.")
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var campaignSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header("CAMPAIGN")
                tField("Candidate Name", text: $candidateName)
                tField("Campaign Name (optional)", text: $campaignName)
                tField("Office Sought", text: $officeSought)
                electionDateRow
            }
        }
    }

    private var districtSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header("DISTRICT")
                tField("State", text: $stateField)
                tField("District (e.g. OH-06, SSD-33, Ward 4)", text: $districtField)
                tField("City / County / Municipality", text: $locality)
            }
        }
    }

    private var dataSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header("WHAT DATA DO YOU NEED?")
                checkboxes
                pickerRow
                longField("Delivery notes (format, segmentation, deadlines)", text: $deliveryNotes)
            }
        }
    }

    private var contactSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                header("CONTACT")
                tField("Your Name", text: $contactName)
                tField("Email", text: $contactEmail, keyboard: .emailAddress)
                tField("Phone (optional)", text: $contactPhone, keyboard: .phonePad)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Haptics.tap()
            submit()
        } label: {
            HStack {
                if submitting { ProgressView().tint(Theme.bg) }
                Text(submitting ? "Submitting…" : "Submit Request")
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

    private var confirmation: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(hex: 0x4caf6e))
                    Text("Request received.")
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("The Colossus team will assemble your district data pull and follow up at \(contactEmail.isEmpty ? "the email you provided" : contactEmail).")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { dismiss() } label: {
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
        submitting = true
        let subject = "District Data Request — \(candidateName)"
        let body = composeBody()
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
        lines.append("=== CAMPAIGN ===")
        lines.append("Candidate: \(candidateName)")
        if !campaignName.isEmpty { lines.append("Campaign: \(campaignName)") }
        lines.append("Office: \(officeSought)")
        if hasElectionDate {
            let f = DateFormatter()
            f.dateStyle = .long
            lines.append("Election Date: \(f.string(from: electionDate))")
        }
        lines.append("")
        lines.append("=== DISTRICT ===")
        lines.append("State: \(stateField)")
        lines.append("District: \(districtField)")
        lines.append("Locality: \(locality)")
        lines.append("")
        lines.append("=== DATA NEEDS ===")
        lines.append("Requested: \(selectedData.sorted().joined(separator: ", "))")
        lines.append("Priority: \(priority.rawValue)")
        if !deliveryNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("Notes: \(deliveryNotes)")
        }
        lines.append("")
        lines.append("=== CONTACT ===")
        lines.append("Name: \(contactName)")
        lines.append("Email: \(contactEmail)")
        lines.append("Phone: \(contactPhone)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Builders

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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

    private func header(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11, weight: .bold))
            .tracking(2)
            .foregroundStyle(Theme.gold)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.sans(11, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.textMuted)
    }

    private func tField(_ l: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(l)
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

    private func longField(_ l: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(l)
            TextEditor(text: text)
                .font(Theme.sans(14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(8)
                .background(Theme.inputBg)
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private var checkboxes: some View {
        let cols = [GridItem(.adaptive(minimum: 150), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(dataOptions, id: \.self) { opt in
                let isOn = selectedData.contains(opt)
                Button {
                    Haptics.tap()
                    if isOn { selectedData.remove(opt) } else { selectedData.insert(opt) }
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

    private var pickerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Priority")
            Menu {
                ForEach(DistrictPriority.allCases) { opt in
                    Button(opt.rawValue) { priority = opt }
                }
            } label: {
                HStack {
                    Text(priority.rawValue)
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

    private var electionDateRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Election Date")
            HStack {
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
}

enum DistrictPriority: String, CaseIterable, Identifiable {
    case urgent = "Urgent — within 48 hours"
    case thisWeek = "This week"
    case thisMonth = "This month"
    case planning = "Planning ahead"
    var id: String { rawValue }
}
