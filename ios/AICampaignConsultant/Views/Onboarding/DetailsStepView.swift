//
//  DetailsStepView.swift
//  AICampaignConsultant
//

import SwiftUI

struct DetailsStepView: View {
    @Binding var office: String
    @Binding var location: String
    @Binding var state: String
    @Binding var district: String
    @Binding var party: Party
    @Binding var electionDate: Date?
    @Binding var role: CandidateRole

    let onBack: () -> Void
    let onContinue: () -> Void

    @FocusState private var focused: Field?
    enum Field { case office, location, state, district }

    var body: some View {
        OnboardingScaffold(step: 2, totalSteps: 3, footer: "STRATEGY · COMMUNICATION · VICTORY") {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("The specifics.")
                        .font(Theme.serif(36, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Jurisdiction-aware advice starts here.")
                        .font(Theme.sans(14))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    field(label: "SPECIFIC OFFICE / SEAT",
                          placeholder: "e.g. City Council, Ward 3",
                          text: $office, focus: .office, next: .state)

                    field(label: "STATE",
                          placeholder: "e.g. Ohio",
                          text: $state, focus: .state, next: .district)

                    field(label: "DISTRICT / JURISDICTION",
                          placeholder: "e.g. OH-59 (House district)",
                          text: $district, focus: .district, next: .location)

                    field(label: "CITY",
                          placeholder: "e.g. Columbus",
                          text: $location, focus: .location, next: nil, submit: .done)

                    labeled("PARTY") {
                        ChipRow(options: Party.allCases, selected: $party) { $0.rawValue }
                    }

                    labeled("ELECTION DATE") {
                        ElectionDateField(date: $electionDate)
                    }

                    labeled("ROLE") {
                        ChipRow(options: CandidateRole.allCases, selected: $role) { $0.rawValue }
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    OutlinedButton(title: "←  Back", action: onBack)
                    PrimaryButton(title: "Continue   →", enabled: canContinue) {
                        Haptics.soft()
                        onContinue()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func field(label: String, placeholder: String, text: Binding<String>,
                       focus: Field, next: Field?, submit: SubmitLabel = .next) -> some View {
        labeled(label) {
            GoldTextField(placeholder: placeholder, text: text, submitLabel: submit) {
                if let next { focused = next } else { focused = nil }
            }
            .focused($focused, equals: focus)
        }
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
            content()
        }
    }

    private var canContinue: Bool {
        !office.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Reusable bits

struct ChipRow<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    var body: some View {
        FlowChipLayout(spacing: 8) {
            ForEach(options) { option in
                let active = option == selected
                Button {
                    Haptics.soft()
                    selected = option
                } label: {
                    Text(label(option))
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(active ? Theme.bg : Theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            active
                            ? AnyShapeStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                           startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Theme.inputBg)
                        )
                        .overlay(
                            Capsule().stroke(active ? Color.clear : Theme.goldFaint, lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Simple wrapping layout for chips.
struct FlowChipLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .init(width: s.width, height: s.height))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

struct ElectionDateField: View {
    @Binding var date: Date?
    @State private var draft: Date = Date()
    @State private var picking: Bool = false

    var body: some View {
        Button {
            draft = date ?? Date()
            picking.toggle()
            Haptics.soft()
        } label: {
            HStack {
                Text(formatted)
                    .font(Theme.sans(17))
                    .foregroundStyle(date == nil ? Theme.textMuted : Theme.textPrimary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Theme.inputBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.goldFaint, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $picking) {
            datePicker
                .presentationDetents([.medium])
                .presentationBackground(Theme.surface)
        }
    }

    private var datePicker: some View {
        VStack(spacing: 16) {
            Text("ELECTION DATE")
                .font(Theme.sans(11, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.gold)
                .padding(.top, 8)
            DatePicker("", selection: $draft, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.gold)
                .padding(.horizontal, 12)
            HStack(spacing: 12) {
                OutlinedButton(title: "Cancel") { picking = false }
                PrimaryButton(title: "Save", enabled: true) {
                    date = draft
                    picking = false
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var formatted: String {
        guard let date else { return "Pick election date" }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}
