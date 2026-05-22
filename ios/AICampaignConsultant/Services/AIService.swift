//
//  AIService.swift
//  AICampaignConsultant
//

import Foundation

enum AIServiceError: Error, LocalizedError {
    case missingConfig
    case http(Int)
    case decoding
    case empty

    var errorDescription: String? {
        switch self {
        case .missingConfig: return "AI service is not configured."
        case .http(let code): return "Server returned status \(code)."
        case .decoding: return "Could not read the response."
        case .empty: return "Empty response from the model."
        }
    }
}

struct AIService {
    // OpenAI-compatible message shape — same JSON the original Vercel handler
    // would have forwarded to Anthropic. We talk to the Rork proxy directly
    // so the app never holds an API key.
    struct WireMessage: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [WireMessage]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg?
        }
        let choices: [Choice]?
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
        }
        let choices: [Choice]?
    }

    private struct StreamRequestBody: Encodable {
        let model: String
        let messages: [WireMessage]
        let temperature: Double
        let max_tokens: Int
        let stream: Bool
    }

    static func send(history: [ChatMessage], systemPrompt: String) async throws -> String {
        let baseURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !baseURL.isEmpty, !key.isEmpty,
              let url = URL(string: "\(baseURL)/v2/vercel/v1/chat/completions") else {
            throw AIServiceError.missingConfig
        }

        var wire: [WireMessage] = [.init(role: "system", content: systemPrompt)]
        wire.append(contentsOf: history.map { .init(role: $0.role.rawValue, content: $0.content) })

        let body = RequestBody(
            model: "anthropic/claude-sonnet-4",
            messages: wire,
            temperature: 0.7,
            max_tokens: 1500
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIServiceError.http(http.statusCode)
        }
        guard let parsed = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw AIServiceError.decoding
        }
        guard let reply = parsed.choices?.first?.message?.content?
            .trimmingCharacters(in: .whitespacesAndNewlines), !reply.isEmpty else {
            throw AIServiceError.empty
        }
        return reply
    }

    /// Streaming variant. Yields incremental text chunks as the model generates them.
    /// The caller is responsible for appending each chunk to the visible message.
    ///
    /// Cloud (Claude) is the primary model. If the network call fails AND the device
    /// supports Apple Foundation Models, we transparently fall back to the on-device
    /// model so the chat keeps working offline. The on-device model is weaker, so we
    /// only use it as a safety net.
    static func stream(
        history: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var producedFromCloud = false
                var cloudError: Error? = nil
                do {
                    let baseURL = Config.EXPO_PUBLIC_TOOLKIT_URL
                    let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
                    guard !baseURL.isEmpty, !key.isEmpty,
                          let url = URL(string: "\(baseURL)/v2/vercel/v1/chat/completions") else {
                        throw AIServiceError.missingConfig
                    }

                    var wire: [WireMessage] = [.init(role: "system", content: systemPrompt)]
                    wire.append(contentsOf: history.map { .init(role: $0.role.rawValue, content: $0.content) })

                    let body = StreamRequestBody(
                        model: "anthropic/claude-sonnet-4",
                        messages: wire,
                        temperature: 0.7,
                        max_tokens: 1500,
                        stream: true
                    )

                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    req.httpBody = try JSONEncoder().encode(body)
                    req.timeoutInterval = 120

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw AIServiceError.http(http.statusCode)
                    }

                    let decoder = JSONDecoder()
                    var produced = false
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let json = String(trimmed.dropFirst(6))
                        guard !json.isEmpty, json != "[DONE]" else { continue }
                        guard let data = json.data(using: .utf8),
                              let chunk = try? decoder.decode(StreamChunk.self, from: data),
                              let piece = chunk.choices?.first?.delta?.content,
                              !piece.isEmpty
                        else { continue }
                        produced = true
                        continuation.yield(piece)
                    }

                    if !produced { throw AIServiceError.empty }
                    producedFromCloud = true
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                    return
                } catch {
                    cloudError = error
                }

                // Cloud failed before yielding anything — try on-device as a fallback.
                if !producedFromCloud, OnDeviceAIService.isAvailable {
                    // Signal a soft handoff so the UI can hint at offline mode.
                    continuation.yield("[Offline mode — using on-device AI]\n\n")
                    do {
                        for try await piece in OnDeviceAIService.stream(history: history, systemPrompt: systemPrompt) {
                            try Task.checkCancellation()
                            continuation.yield(piece)
                        }
                        continuation.finish()
                        return
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch {
                        // Fall through and surface the original cloud error below.
                    }
                }

                continuation.finish(throwing: cloudError ?? AIServiceError.empty)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Web-search-enabled, non-streaming reply. Routes to Anthropic's native
    /// `web_search_20250305` tool via `/v1/messages`. Claude decides when to search,
    /// runs up to `maxSearches` queries server-side, and returns a single answer
    /// string with full source URLs embedded inline (per system-prompt instruction).
    ///
    /// We use non-streaming on purpose: the Anthropic Messages SSE event shape is
    /// different from chat/completions, and web-search answers come back as one
    /// coherent block after research finishes anyway.
    static func sendWithWebSearch(
        history: [ChatMessage],
        systemPrompt: String,
        maxSearches: Int = 4,
        allowedDomains: [String]? = nil,
        researchMode: Bool = false
    ) async throws -> String {
        let baseURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !baseURL.isEmpty, !key.isEmpty,
              let url = URL(string: "\(baseURL)/v2/vercel/v1/messages") else {
            throw AIServiceError.missingConfig
        }

        let webGuidance = """
        You have a web_search tool available. Use it whenever the user asks about \
        current events, recent polling, opponent activity, news coverage, FEC filings, \
        donor research, or anything time-sensitive that may have changed since training. \
        For every factual claim sourced from the web, write the full https:// URL inline \
        in parentheses next to the claim. Do NOT use [1][2] citation markers — always \
        write the full URL. If a question is general strategy and does not need fresh \
        data, just answer directly without searching.
        """

        let researchGuidance = """
        RESEARCH MODE — You have a web_search tool restricted to FEC.gov and \
        Ballotpedia.org. Use it aggressively to pull real campaign-finance and \
        candidate data for this question. Prefer these search patterns:
        - For donor / fundraising / spending questions: search FEC.gov for the \
          candidate's committee filings, totals, top contributors, independent \
          expenditures, and PAC activity. Use api.open.fec.gov or docquery.fec.gov \
          links when available.
        - For opponent profile, electoral history, endorsements, district demographics, \
          past results, ballot access, primary calendars: search Ballotpedia.org.
        Always cite by writing the full https:// URL inline in parentheses next to \
        each fact. Do NOT use [1][2] markers. If a question genuinely cannot be \
        answered from FEC or Ballotpedia (e.g. internal polling, breaking news), \
        say so plainly and suggest the user toggle off Research mode for general \
        web search. Lead with the data, then a short strategic interpretation tied \
        to the candidate's race.
        """

        let combinedSystem = systemPrompt + "\n\n" + (researchMode ? researchGuidance : webGuidance)

        // Anthropic Messages API expects role/content pairs WITHOUT a system role
        // in the messages array — system is a top-level field.
        let wireMessages: [[String: Any]] = history.map { msg in
            ["role": msg.role == .assistant ? "assistant" : "user", "content": msg.content]
        }

        var webTool: [String: Any] = [
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": maxSearches
        ]
        if let allowedDomains, !allowedDomains.isEmpty {
            webTool["allowed_domains"] = allowedDomains
        }

        let body: [String: Any] = [
            "model": "anthropic/claude-sonnet-4",
            "max_tokens": 2048,
            "system": combinedSystem,
            "tools": [webTool],
            "messages": wireMessages
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIServiceError.http(http.statusCode)
        }

        struct AnthropicResponse: Decodable {
            struct Block: Decodable {
                let type: String
                let text: String?
            }
            let content: [Block]?
        }

        guard let parsed = try? JSONDecoder().decode(AnthropicResponse.self, from: data) else {
            throw AIServiceError.decoding
        }
        let answer = (parsed.content ?? [])
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { throw AIServiceError.empty }
        return answer
    }

    /// Voter-tools-enabled call. Runs Claude with custom tools that query the
    /// candidate's district voter database via Supabase RPCs. Tools execute
    /// client-side under the user's JWT (RLS handles district scoping). The
    /// loop runs until the model returns a plain-text answer or hits maxTurns.
    static func sendWithVoterTools(
        history: [ChatMessage],
        systemPrompt: String,
        session: SupabaseSession,
        maxTurns: Int = 4
    ) async throws -> String {
        let baseURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !baseURL.isEmpty, !key.isEmpty,
              let url = URL(string: "\(baseURL)/v2/vercel/v1/messages") else {
            throw AIServiceError.missingConfig
        }

        let dataGuidance = """
        DISTRICT DATA MODE — You have tools wired to the candidate's live voter file. Use them aggressively. Whenever the candidate asks "where should I door-knock first," "what's my electorate look like," or any question about district turnout, precincts, party mix, or specific voters, CALL THE TOOLS first and answer with real numbers — never generic advice. Cite the actual counts and precinct codes you get back. After presenting the data, give a short strategic interpretation tied to this candidate's race level and party.

        Available tools:
        - get_district_summary(): total voters, party mix, voter status counts.
        - get_party_breakdown(by): "overall", "precinct", or "age".
        - get_turnout_history(election_count): last N generals + primaries.
        - get_top_precincts(metric): "voter_count" or "turnout_rate".
        - find_voters(filters): party, age_min, age_max, status, precinct, turnout_min, turnout_max. Returns total + sample of voters.

        If a tool returns zero rows or empty results, say so plainly — the ingest pipeline may not have loaded the district yet. Do not invent numbers.
        """

        let combinedSystem = systemPrompt + "\n\n" + dataGuidance

        let tools: [[String: Any]] = [
            [
                "name": "get_district_summary",
                "description": "Total registered voters, party mix, and voter status counts for the candidate's district.",
                "input_schema": ["type": "object", "properties": [:], "required": []] as [String: Any]
            ],
            [
                "name": "get_party_breakdown",
                "description": "Party-affiliation breakdown. Group by 'overall' (default), 'precinct' (top 50), or 'age' (decade buckets).",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "by": ["type": "string", "enum": ["overall", "precinct", "age"]]
                    ],
                    "required": []
                ] as [String: Any]
            ],
            [
                "name": "get_turnout_history",
                "description": "Turnout in the last N generals and primaries.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "election_count": ["type": "integer", "minimum": 1, "maximum": 10]
                    ],
                    "required": []
                ] as [String: Any]
            ],
            [
                "name": "get_top_precincts",
                "description": "Top 5 precincts by either total voter_count or recent turnout_rate.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "metric": ["type": "string", "enum": ["voter_count", "turnout_rate"]]
                    ],
                    "required": []
                ] as [String: Any]
            ],
            [
                "name": "find_voters",
                "description": "Count and sample voters that match a filter. Filters: party (D/R/U), status (ACTIVE/CONFIRMATION/CANCELLED), precinct, age_min, age_max, turnout_min, turnout_max, search (name).",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "party": ["type": "string"],
                        "status": ["type": "string"],
                        "precinct": ["type": "string"],
                        "age_min": ["type": "integer"],
                        "age_max": ["type": "integer"],
                        "turnout_min": ["type": "integer"],
                        "turnout_max": ["type": "integer"],
                        "search": ["type": "string"]
                    ],
                    "required": []
                ] as [String: Any]
            ]
        ]

        var conversation: [[String: Any]] = history.map { msg in
            ["role": msg.role == .assistant ? "assistant" : "user", "content": msg.content]
        }

        var finalText = ""

        for _ in 0..<maxTurns {
            let body: [String: Any] = [
                "model": "anthropic/claude-sonnet-4",
                "max_tokens": 2048,
                "system": combinedSystem,
                "tools": tools,
                "messages": conversation
            ]

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 90

            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw AIServiceError.http(http.statusCode)
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]] else {
                throw AIServiceError.decoding
            }
            let stopReason = json["stop_reason"] as? String ?? ""

            // Collect text blocks for the final answer.
            let textBlocks = content.compactMap { block -> String? in
                if block["type"] as? String == "text" { return block["text"] as? String }
                return nil
            }
            if !textBlocks.isEmpty {
                finalText = textBlocks.joined(separator: "\n")
            }

            // Detect tool calls.
            let toolUses = content.filter { ($0["type"] as? String) == "tool_use" }
            if toolUses.isEmpty || stopReason != "tool_use" {
                return finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (try await fallbackText(content: content)) : finalText
            }

            // Append the assistant message with its tool_use blocks verbatim.
            conversation.append(["role": "assistant", "content": content])

            // Execute each tool and build tool_result blocks.
            var resultBlocks: [[String: Any]] = []
            for use in toolUses {
                guard let id = use["id"] as? String,
                      let name = use["name"] as? String else { continue }
                let input = (use["input"] as? [String: Any]) ?? [:]
                let resultJSON = await runVoterTool(name: name, input: input, session: session)
                resultBlocks.append([
                    "type": "tool_result",
                    "tool_use_id": id,
                    "content": resultJSON
                ])
            }
            conversation.append(["role": "user", "content": resultBlocks])
        }

        if finalText.isEmpty { throw AIServiceError.empty }
        return finalText
    }

    private static func fallbackText(content: [[String: Any]]) async throws -> String {
        let text = content.compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw AIServiceError.empty }
        return text
    }

    /// Dispatches a tool call to VoterDataService and returns a JSON string
    /// suitable for tool_result.content (Anthropic accepts string or blocks).
    private static func runVoterTool(
        name: String,
        input: [String: Any],
        session: SupabaseSession
    ) async -> String {
        do {
            switch name {
            case "get_district_summary":
                let s = try await VoterDataService.districtSummary(session: session)
                return jsonString([
                    "total_voters": s.total_voters,
                    "state_code": s.state_code ?? "",
                    "district": s.district ?? "",
                    "party": [
                        "democrat": s.party.democrat,
                        "republican": s.party.republican,
                        "unaffiliated": s.party.unaffiliated,
                        "other": s.party.other
                    ],
                    "status": [
                        "active": s.status.active,
                        "confirmation": s.status.confirmation,
                        "cancelled": s.status.cancelled
                    ]
                ])
            case "get_party_breakdown":
                let by = (input["by"] as? String) ?? "overall"
                let buckets = try await VoterDataService.partyBreakdown(session: session, by: by)
                return jsonString(["by": by, "buckets": buckets.map {
                    ["label": $0.label, "dem": $0.dem as Any, "rep": $0.rep as Any, "total": $0.total as Any]
                }])
            case "get_turnout_history":
                let n = (input["election_count"] as? Int) ?? 4
                let t = try await VoterDataService.turnoutHistory(session: session, electionCount: n)
                return jsonString([
                    "eligible": t.eligible,
                    "generals": t.generals.map { ["date": $0.election_date, "voted": $0.voted] },
                    "primaries": t.primaries.map { ["date": $0.election_date, "voted": $0.voted] }
                ])
            case "get_top_precincts":
                let metric = (input["metric"] as? String) ?? "voter_count"
                let p = try await VoterDataService.topPrecincts(session: session, metric: metric)
                return jsonString(["metric": metric, "precincts": p.map {
                    ["precinct": $0.precinct_code ?? "", "voter_count": $0.voter_count as Any, "turnout_rate": $0.turnout_rate as Any]
                }])
            case "find_voters":
                var f = VoterFilters()
                f.party = input["party"] as? String
                f.status = input["status"] as? String
                f.precinct = input["precinct"] as? String
                f.ageMin = input["age_min"] as? Int
                f.ageMax = input["age_max"] as? Int
                f.turnoutMin = input["turnout_min"] as? Int
                f.turnoutMax = input["turnout_max"] as? Int
                f.search = input["search"] as? String
                let p = try await VoterDataService.findVoters(session: session, filters: f, page: 0, pageSize: 10)
                return jsonString([
                    "total": p.total,
                    "sample": p.rows.prefix(10).map { r in
                        [
                            "name": r.fullName,
                            "age": r.age as Any,
                            "party": r.party ?? "",
                            "precinct": r.precinct ?? "",
                            "turnout_score": r.turnout_score as Any
                        ] as [String: Any]
                    }
                ])
            default:
                return "{\"error\":\"unknown tool\"}"
            }
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return jsonString(["error": msg])
        }
    }

    private static func jsonString(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(
                withJSONObject: obj,
                options: [.fragmentsAllowed]
              ),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    static func systemPrompt(for c: CandidateProfile) -> String {
        """
        You are Colossus Campaign OS, the AI campaign consultant by Colossus Strategies & Consulting — a world-class political campaign advisor. Your tagline is "Strategy. Communication. Victory."

        CANDIDATE CONTEXT:
        - Name: \(c.name)
        - Race type: \(c.raceType.label)
        - Office sought: \(c.office)
        - Location: \(c.location)

        Always address them by name. Tailor ALL advice specifically to their race type and level. For local races keep advice grassroots and practical. For statewide/congressional include earned media, digital strategy, and larger-scale operations. Be practical, direct, and actionable. Use headers and bullet points where helpful.
        """
    }
}
