//
//  ChatMessage.swift
//  AICampaignConsultant
//

import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date = .init()
}
