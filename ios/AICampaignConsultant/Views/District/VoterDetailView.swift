//
//  VoterDetailView.swift
//  AICampaignConsultant
//

import SwiftUI

struct VoterDetailView: View {
    let voterId: String
    let session: SupabaseSession

    @State private var detail: VoterDetail?
    @State private var loading: Bool = true
    @State private var errorMsg: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView().tint(Theme.gold).padding(40)
                } else if let err = errorMsg {
                    Text(err)
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding()
                } else if let v = detail?.voter {
                    content(v, history: detail?.history ?? [])
                } else {
                    Text("Not found.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding()
                }
            }
            .background(Theme.bg)
            .navigationTitle("Voter")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private func content(_ v: VoterFull, history: [VoterHistoryRow]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(fullName(v))
                    .font(Theme.serif(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text([v.party_affiliation, v.voter_status].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.sans(12, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Address card
            card {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("ADDRESS")
                    if let a = v.residential_address {
                        Text(a).font(Theme.sans(14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    }
                    Text([v.city, v.zip].compactMap { $0 }.joined(separator: ", "))
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Registration & districts
            card {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("REGISTRATION")
                    row("DOB", v.dob)
                    row("Registered", v.registration_date)
                    row("Precinct", v.precinct_code)
                    row("County", v.county)
                    row("Congressional", v.congressional_district)
                    row("State Rep", v.state_rep_district)
                    row("State Sen", v.state_senate_district)
                }
            }

            // History
            card {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("VOTE HISTORY")
                    if history.isEmpty {
                        Text("No recorded vote history.")
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.textMuted)
                    } else {
                        ForEach(history) { h in
                            HStack {
                                Text(h.election_date)
                                    .font(Theme.sans(12, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(h.election_type)
                                    .font(Theme.sans(10, weight: .bold))
                                    .foregroundStyle(Theme.gold)
                                Spacer()
                                if let p = h.party_voted, !p.isEmpty {
                                    Text(p).font(Theme.sans(11)).foregroundStyle(Theme.textMuted)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 16)
    }

    private func fullName(_ v: VoterFull) -> String {
        [v.first_name, v.middle_name, v.last_name, v.suffix]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1)
            )
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s)
            .font(Theme.sans(10, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Theme.gold)
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let v = value, !v.isEmpty {
            HStack {
                Text(label).font(Theme.sans(11, weight: .semibold)).foregroundStyle(Theme.textMuted)
                Spacer()
                Text(v).font(Theme.sans(12, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private func load() async {
        loading = true
        do {
            detail = try await VoterDataService.voterDetail(session: session, voterId: voterId)
        } catch {
            errorMsg = (error as? LocalizedError)?.errorDescription ?? "Could not load voter."
        }
        loading = false
    }
}
