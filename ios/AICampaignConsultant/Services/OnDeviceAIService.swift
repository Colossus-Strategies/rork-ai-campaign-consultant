//
//  OnDeviceAIService.swift
//  AICampaignConsultant
//
//  On-device fallback using Apple Foundation Models (iOS 26+).
//  Used when the cloud model is unreachable (no internet, server error).
//  The on-device model is small and weaker at reasoning than Claude, so it's
//  intentionally a fallback — never the default.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDeviceAIError: Error, LocalizedError {
    case unsupportedOS
    case appleIntelligenceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "On-device AI requires iOS 26 or later."
        case .appleIntelligenceUnavailable(let reason):
            return reason
        }
    }
}

struct OnDeviceAIService {

    /// True when the device can run Apple Foundation Models right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Streams a response from the on-device model. Mirrors `AIService.stream`'s
    /// signature so callers can swap implementations without changing UI code.
    static func stream(
        history: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let task = Task {
                    do {
                        let availability = SystemLanguageModel.default.availability
                        switch availability {
                        case .available:
                            break
                        case .unavailable(.appleIntelligenceNotEnabled):
                            throw OnDeviceAIError.appleIntelligenceUnavailable(
                                "Enable Apple Intelligence in Settings to use offline mode."
                            )
                        case .unavailable(.modelNotReady):
                            throw OnDeviceAIError.appleIntelligenceUnavailable(
                                "The on-device model is still downloading. Try again shortly."
                            )
                        case .unavailable(.deviceNotEligible):
                            throw OnDeviceAIError.appleIntelligenceUnavailable(
                                "This device doesn't support on-device AI."
                            )
                        @unknown default:
                            throw OnDeviceAIError.appleIntelligenceUnavailable(
                                "On-device AI is unavailable."
                            )
                        }

                        let session = LanguageModelSession {
                            systemPrompt
                            "You are running in offline mode on the user's device. Keep answers concise (under 250 words) and practical."
                        }

                        // Combine prior turns into a single prompt — the on-device
                        // session is created fresh each call to keep latency predictable
                        // and avoid context-window blow-ups on long chats.
                        let combined = history.map { msg -> String in
                            let label = msg.role == .user ? "User" : "Assistant"
                            return "\(label): \(msg.content)"
                        }.joined(separator: "\n\n")

                        let userPrompt = combined.isEmpty
                            ? "Please respond."
                            : "Conversation so far:\n\(combined)\n\nRespond as the assistant."

                        var lastEmitted = ""
                        for try await partial in session.streamResponse(to: userPrompt) {
                            try Task.checkCancellation()
                            let full = partial.content
                            if full.count > lastEmitted.count {
                                let delta = String(full.dropFirst(lastEmitted.count))
                                lastEmitted = full
                                if !delta.isEmpty { continuation.yield(delta) }
                            } else if full != lastEmitted {
                                // Model rewrote earlier text — emit the whole thing.
                                lastEmitted = full
                                continuation.yield(full)
                            }
                        }
                        continuation.finish()
                    } catch is CancellationError {
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
                return
            }
            #endif
            continuation.finish(throwing: OnDeviceAIError.unsupportedOS)
        }
    }
}
