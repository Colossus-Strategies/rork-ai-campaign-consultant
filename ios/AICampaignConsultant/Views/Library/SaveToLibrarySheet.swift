//
//  SaveToLibrarySheet.swift
//  AICampaignConsultant
//
//  F07 — sheet for saving an AI output (or any text) to the candidate's library.
//

import SwiftUI

struct SaveToLibrarySheet: View {
    let initialBody: String
    var initialName: String = ""
    let onClose: () -> Void
    let onSaved: (SavedItem) -> Void

    @State private var name: String
    @State private var category: SavedItem.Category = .script
    @State private var notes: String = ""
    @State private var content: String

    init(initialBody: String, initialName: String = "", onClose: @escaping () -> Void, onSaved: @escaping (SavedItem) -> Void) {
        self.initialBody = initialBody
        self.initialName = initialName
        self.onClose = onClose
        self.onSaved = onSaved
        _name = State(initialValue: initialName.isEmpty ? Self.suggestName(from: initialBody) : initialName)
        _content = State(initialValue: initialBody)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        field(label: "Name") {
                            TextField("", text: $name)
                                .font(Theme.sans(15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.gold)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY")
                                .font(Theme.sans(10, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(Theme.goldDim)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(SavedItem.Category.allCases) { c in
                                        Button {
                                            Haptics.tap()
                                            category = c
                                        } label: {
                                            Text(c.rawValue)
                                                .font(Theme.sans(12, weight: .bold))
                                                .foregroundStyle(category == c ? Theme.bg : Theme.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(category == c ? Theme.gold : Theme.surface)
                                                .overlay(Capsule().stroke(Theme.goldFaint, lineWidth: 1))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        field(label: "Notes (optional)") {
                            TextField("Why you saved this…", text: $notes, axis: .vertical)
                                .font(Theme.sans(14))
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.gold)
                                .lineLimit(2...4)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONTENT")
                                .font(Theme.sans(10, weight: .bold))
                                .tracking(1.6)
                                .foregroundStyle(Theme.goldDim)
                            TextEditor(text: $content)
                                .scrollContentBackground(.hidden)
                                .font(Theme.sans(14))
                                .foregroundStyle(Theme.textPrimary)
                                .tint(Theme.gold)
                                .frame(minHeight: 200)
                                .padding(10)
                                .background(Theme.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1))
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Save to Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onClose() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let item = SavedItem(
                            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : name,
                            category: category,
                            notes: notes,
                            body: content
                        )
                        LibraryStore.shared.add(item)
                        onSaved(item)
                    }
                    .font(Theme.sans(15, weight: .bold))
                    .foregroundStyle(Theme.gold)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func field<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(Theme.sans(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.goldDim)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.inputBg)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.goldFaint, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
        }
    }

    static func suggestName(from body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        let cap = String(firstLine.prefix(60))
        return cap.isEmpty ? "Saved item" : cap
    }
}
