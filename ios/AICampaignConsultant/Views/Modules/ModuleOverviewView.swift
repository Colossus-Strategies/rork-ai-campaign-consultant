//
//  ModuleOverviewView.swift
//  AICampaignConsultant
//
//  Screen 08 — Module overview with sub-topics + "Ask the coach" seed.
//

import SwiftUI

struct ModuleOverviewView: View {
    let module: CampaignModule
    let profile: CandidateProfile
    let onOpenTopic: (SubTopic) -> Void
    let onAskCoach: (String) -> Void

    private var progress: Double { ProgressStore.shared.completionFraction(in: module) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                blurbCard
                askCoachCard
                topicsHeader
                topicsList
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(module.accent.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: module.symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(module.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.title)
                        .font(Theme.serif(22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(module.tagline)
                        .font(Theme.sans(12))
                        .italic()
                        .foregroundStyle(Theme.gold)
                }
            }
            RaceContextBadge(profile: profile, compact: true)

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.inputBg)
                        Capsule().fill(module.accent)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
                Text("\(Int(progress * 100))% done")
                    .font(Theme.sans(11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.top, 4)
        }
    }

    private var blurbCard: some View {
        Text(module.blurb)
            .font(Theme.sans(14))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1))
            .clipShape(.rect(cornerRadius: 12))
    }

    private var askCoachCard: some View {
        Button {
            Haptics.tap()
            onAskCoach(module.seedPrompt)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 38, height: 38)
                    .background(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask the coach")
                        .font(Theme.serif(15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\u{201C}\(module.seedPrompt)\u{201D}")
                        .font(Theme.sans(12))
                        .italic()
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.goldDim)
            }
            .padding(14)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.5), lineWidth: 1.5))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var topicsHeader: some View {
        Text("TRAINING TOPICS")
            .font(Theme.sans(10, weight: .bold))
            .tracking(2.0)
            .foregroundStyle(Theme.goldDim)
            .padding(.top, 4)
    }

    private var topicsList: some View {
        VStack(spacing: 10) {
            ForEach(module.topics) { topic in
                Button {
                    Haptics.tap()
                    onOpenTopic(topic)
                } label: {
                    topicRow(topic)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func topicRow(_ topic: SubTopic) -> some View {
        let done = ProgressStore.shared.completedCount(in: topic)
        let total = topic.steps.count
        let pct = total == 0 ? 0.0 : Double(done) / Double(total)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.goldFaint, lineWidth: 2)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(module.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text("\(done)/\(total)")
                    .font(Theme.sans(9, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.title)
                    .font(Theme.serif(15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(topic.summary)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldDim)
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.goldFaint, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 14))
    }
}
