//
//  DeepDiveView.swift
//  AICampaignConsultant
//
//  Screen 09 — Stepped deep-dive content with completion state per step
//  and "Practice with the coach" pivot to chat (F04→F05).
//

import SwiftUI

struct DeepDiveView: View {
    let module: CampaignModule
    let topic: SubTopic
    let profile: CandidateProfile
    let onPracticeWithCoach: (String) -> Void

    @State private var expandedStepId: String? = nil
    private let progress = ProgressStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                stepsHeader
                ForEach(Array(topic.steps.enumerated()), id: \.element.id) { idx, step in
                    stepCard(index: idx + 1, step: step)
                }
                practiceCTA
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Theme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: module.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(module.accent)
                Text(module.title.uppercased())
                    .font(Theme.sans(10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(module.accent)
            }
            Text(topic.title)
                .font(Theme.serif(24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(topic.summary)
                .font(Theme.sans(14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            RaceContextBadge(profile: profile, compact: true)
                .padding(.top, 4)
        }
    }

    private var stepsHeader: some View {
        let done = progress.completedCount(in: topic)
        return HStack {
            Text("STEPS")
                .font(Theme.sans(10, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(Theme.goldDim)
            Spacer()
            Text("\(done) of \(topic.steps.count) complete")
                .font(Theme.sans(11, weight: .bold))
                .foregroundStyle(Theme.textMuted)
        }
    }

    @ViewBuilder
    private func stepCard(index: Int, step: DeepDiveStep) -> some View {
        let isDone = progress.isComplete(step.id)
        let isExpanded = expandedStepId == step.id

        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptics.tap()
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedStepId = isExpanded ? nil : step.id
                }
            } label: {
                HStack(spacing: 12) {
                    badge(index: index, isDone: isDone)
                    Text(step.title)
                        .font(Theme.serif(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.goldDim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(step.body)
                    .font(Theme.sans(14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let ex = step.exercise {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DRILL")
                            .font(Theme.sans(9, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(module.accent)
                        Text(ex)
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.inputBg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(module.accent.opacity(0.4), lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 10))
                }

                HStack(spacing: 10) {
                    Button {
                        Haptics.success()
                        withAnimation { progress.setComplete(step.id, !isDone) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            Text(isDone ? "Completed" : "Mark complete")
                        }
                        .font(Theme.sans(13, weight: .bold))
                        .foregroundStyle(isDone ? Theme.bg : Theme.gold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isDone
                                    ? AnyShapeStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Color.clear))
                        .overlay(Capsule().stroke(Theme.gold, lineWidth: 1.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Haptics.tap()
                        let seed = "I'm working on '\(step.title)' in \(module.title). Coach me through it with my race in mind."
                        onPracticeWithCoach(seed)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Practice with coach")
                        }
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isDone ? module.accent.opacity(0.55) : Theme.goldFaint, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func badge(index: Int, isDone: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isDone ? module.accent : Theme.inputBg)
                .frame(width: 30, height: 30)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.bg)
            } else {
                Text("\(index)")
                    .font(Theme.sans(13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .overlay(Circle().stroke(module.accent.opacity(isDone ? 0.0 : 0.4), lineWidth: 1))
    }

    private var practiceCTA: some View {
        Button {
            Haptics.tap()
            let seed = "Walk me through '\(topic.title)' with my race in mind, step by step."
            onPracticeWithCoach(seed)
        } label: {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Practice this with your coach")
                    .font(Theme.serif(14, weight: .bold))
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(Theme.bg)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(LinearGradient(colors: [Theme.goldLight, Theme.gold],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}
