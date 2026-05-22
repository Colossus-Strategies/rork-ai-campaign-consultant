//
//  Module.swift
//  AICampaignConsultant
//
//  Content model for the six campaign modules + sub-topics + deep-dive steps.
//  This drives Home (Screen 07), Module Overview (Screen 08), and the
//  stepped Deep Dive (Screen 09).
//

import Foundation
import SwiftUI

struct CampaignModule: Identifiable, Hashable {
    let id: String
    let title: String
    let tagline: String
    let symbol: String          // SF Symbol
    let accent: Color
    let blurb: String
    let topics: [SubTopic]
    let seedPrompt: String      // Prefilled chat prompt for "Ask the coach"
    let isComplianceModule: Bool
}

struct SubTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let steps: [DeepDiveStep]
}

struct DeepDiveStep: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let exercise: String?
}

enum ModuleLibrary {
    static let modules: [CampaignModule] = [
        fundraising,
        voterContact,
        messaging,
        field,
        compliance,
        earnedMedia,
    ]

    static func find(id: String) -> CampaignModule? {
        modules.first { $0.id == id }
    }

    // MARK: - 1. Fundraising Coach
    static let fundraising = CampaignModule(
        id: "fundraising",
        title: "Fundraising Coach",
        tagline: "Money is oxygen. Train the discipline.",
        symbol: "dollarsign.circle.fill",
        accent: Color(hex: 0xc9a84c),
        blurb: "Build a real call-time habit, work your donor list, and ask without flinching. Practical drills for every dollar level.",
        topics: [
            SubTopic(
                id: "calltime",
                title: "Call Time Training",
                summary: "The single highest-leverage activity in any campaign. Build a 90-minute discipline.",
                steps: [
                    DeepDiveStep(
                        id: "ct-1",
                        title: "Why call time wins races",
                        body: "Call time is the unglamorous core of every funded race. You will raise more money on the phone, one ask at a time, than any other activity. The candidates who win are the ones who treat call time as a non-negotiable habit — not a chore.\n\nKey truth: nobody gives unless you ask. And nobody gives big unless you ask big.",
                        exercise: nil
                    ),
                    DeepDiveStep(
                        id: "ct-2",
                        title: "Build your prospect list",
                        body: "Start with 200 names: family, friends, professional contacts, every wedding/holiday card you've sent. Add LinkedIn. Add anyone who maxed to a similar race. Rate each A/B/C and assign an ask amount. An A-list ask is the contribution maximum; a C-list ask is $100.",
                        exercise: "List your top 25 prospects with an ask amount next to each one. Don't move on until 25 names are written down."
                    ),
                    DeepDiveStep(
                        id: "ct-3",
                        title: "Block the time",
                        body: "Two 90-minute blocks per day, four days a week. Phone in hand. Door closed. Spreadsheet open. No social, no email, no campaign manager interrupting unless someone is on fire.",
                        exercise: "Put two blocks on your calendar for tomorrow. Title them 'CALL TIME — DO NOT DISTURB.'"
                    ),
                    DeepDiveStep(
                        id: "ct-4",
                        title: "The opening script",
                        body: "Open warm, get to the ask in under 90 seconds. 'Hey [name], it's [you]. I'm running for [office] because [one sentence reason]. I'm calling personally because I'd be grateful for your support — can I count on you for $[ask]?'\n\nThen shut up. Silence is your friend.",
                        exercise: "Write your opening in your own voice and read it aloud three times until it sounds like you, not a script."
                    ),
                    DeepDiveStep(
                        id: "ct-5",
                        title: "Handling objections",
                        body: "'I need to think about it' → 'Totally fair. Can I count on $X this week and the rest by end of month?'\n'I'm tapped out' → 'I hear you — would $100 still be possible? Every bit helps me hit my goal this week.'\n'Let me check with my spouse' → 'Of course. When can I follow up — Wednesday?'\n\nNever leave a call without a next step.",
                        exercise: "Practice all three rebuttals out loud. Yes, out loud."
                    ),
                    DeepDiveStep(
                        id: "ct-6",
                        title: "Follow-through and tracking",
                        body: "Every yes needs a same-day text or email with the contribution link. Every 'maybe' needs a calendar follow-up. Every no gets a thank-you note. Track call attempts, asks made, dollars committed, dollars received — review weekly.",
                        exercise: "Pick a tracking tool today (NGP, ActionNetwork, Anedot, or a Google Sheet). Set it up before your first call block."
                    ),
                ]
            ),
            SubTopic(
                id: "donor-tiers",
                title: "Tiered Donor Strategy",
                summary: "Match ask amount to relationship and capacity — not to your nerves.",
                steps: [
                    DeepDiveStep(id: "dt-1", title: "Segment your list", body: "Split donors into Major (max-out capable), Mid ($500–$2,499), and Grassroots (<$500). Each tier gets a different ask, cadence, and steward.", exercise: nil),
                    DeepDiveStep(id: "dt-2", title: "Major donor cultivation", body: "Coffee. House parties. Quarterly briefings. They give once and big — but only after they feel like an insider.", exercise: "Pick three Major prospects and put a coffee on the calendar in the next 14 days."),
                    DeepDiveStep(id: "dt-3", title: "Grassroots flywheel", body: "Low-dollar online list grows through earned media moments, ActBlue/WinRed pages, and event ticketing. Every supporter becomes a small donor and a volunteer.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "events",
                title: "Fundraising Events",
                summary: "Host events that pay for themselves and seed the next round.",
                steps: [
                    DeepDiveStep(id: "ev-1", title: "House parties", body: "Lowest cost, highest ROI. Find a host willing to invite their network. Your job: 8-minute speech, then work the room.", exercise: "Identify three potential hosts this week."),
                    DeepDiveStep(id: "ev-2", title: "The kickoff event", body: "Public launch with press, energy, a clear ask. Goal: hit a published fundraising number to signal viability.", exercise: nil),
                ]
            ),
        ],
        seedPrompt: "Coach me on call time. I have an hour today — what should I do?",
        isComplianceModule: false
    )

    // MARK: - 2. Voter Contact
    static let voterContact = CampaignModule(
        id: "voter-contact",
        title: "Voter Contact",
        tagline: "Doors, phones, texts — the votes are out there.",
        symbol: "person.3.fill",
        accent: Color(hex: 0x6fa0e8),
        blurb: "Build a contact universe, hit your daily IDs, and convert leaners into hard yeses.",
        topics: [
            SubTopic(
                id: "vc-canvass",
                title: "Door Canvassing",
                summary: "The most persuasive thing in politics is a real human at the door.",
                steps: [
                    DeepDiveStep(id: "vc-1", title: "Your universe", body: "Pull the voter file. Target high-propensity voters in persuadable households first, then sporadic supporters for turnout.", exercise: "Decide how many doors you personally will knock per week. Write it down."),
                    DeepDiveStep(id: "vc-2", title: "The 30-second pitch", body: "Name, office, one issue they care about, ask for the vote. Shut up and listen for 20 seconds.", exercise: nil),
                    DeepDiveStep(id: "vc-3", title: "ID and follow-up", body: "Code every door: 1 (hard yes), 2 (lean), 3 (undecided), 4 (lean opp), 5 (hard no). The 2s and 3s are your real work.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "vc-phones",
                title: "Phone Banks",
                summary: "Scale ID and turnout with disciplined volunteer phone time.",
                steps: [
                    DeepDiveStep(id: "vc-4", title: "Recruit and retain", body: "Lead with food, purpose, and a clear shift script. Track who shows up — those are your future leaders.", exercise: "Schedule a phone bank in the next 10 days."),
                    DeepDiveStep(id: "vc-5", title: "Scripts that work", body: "Short, conversational, ends with an explicit ask: 'Can the candidate count on your vote?'", exercise: nil),
                ]
            ),
            SubTopic(
                id: "vc-text",
                title: "Peer-to-Peer Text",
                summary: "Highest-ROI digital contact in modern races.",
                steps: [
                    DeepDiveStep(id: "vc-6", title: "Tools and compliance", body: "Use a P2P platform with consent records. Text is regulated — segment by opt-in.", exercise: nil),
                ]
            ),
        ],
        seedPrompt: "Help me build a 90-day voter contact plan for my race.",
        isComplianceModule: false
    )

    // MARK: - 3. Messaging
    static let messaging = CampaignModule(
        id: "messaging",
        title: "Messaging",
        tagline: "What you stand for. In one sentence.",
        symbol: "quote.bubble.fill",
        accent: Color(hex: 0xb088ff),
        blurb: "Sharpen your core message, stay on it under pressure, and translate it to mail, video, and the stump.",
        topics: [
            SubTopic(
                id: "msg-core",
                title: "Core Message",
                summary: "If you can't say it in one sentence, you don't have one.",
                steps: [
                    DeepDiveStep(id: "msg-1", title: "The one-sentence test", body: "Write your message: 'I'm running because ___, and I'll fight for ___.' Read it to five people. If they paraphrase it back correctly, you have a message.", exercise: "Write your one sentence. Today."),
                    DeepDiveStep(id: "msg-2", title: "Three pillars", body: "Pick three issues. Not five. Three. Every speech, mailer, and ad ladders up to those three.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "msg-discipline",
                title: "Message Discipline",
                summary: "Stay on message under pressure. Always.",
                steps: [
                    DeepDiveStep(id: "msg-3", title: "Bridge phrases", body: "'That's an important question, and here's what I think it's really about…' Practice bridging from any topic back to your pillars.", exercise: "Write three bridges from off-topic questions to your top issue."),
                ]
            ),
            SubTopic(
                id: "msg-mail",
                title: "Mail & Video",
                summary: "How your message shows up in paid comms.",
                steps: [
                    DeepDiveStep(id: "msg-4", title: "Mailer anatomy", body: "Big photo, one headline, one ask, one CTA. If grandma needs reading glasses to read it, redesign.", exercise: nil),
                    DeepDiveStep(id: "msg-5", title: "Disclaimers on paid comms", body: "Every paid comm needs a 'Paid for by' disclaimer that meets jurisdiction rules. Verify the exact wording with your treasurer or compliance counsel before printing.", exercise: nil),
                ]
            ),
        ],
        seedPrompt: "Help me write a sharp one-sentence message for my race.",
        isComplianceModule: false
    )

    // MARK: - 4. Field Operations
    static let field = CampaignModule(
        id: "field",
        title: "Field Operations",
        tagline: "Volunteers, turf, GOTV — the ground game.",
        symbol: "map.fill",
        accent: Color(hex: 0x4dc8a8),
        blurb: "Recruit a volunteer corps, cut turf intelligently, and run a GOTV that actually pulls voters.",
        topics: [
            SubTopic(
                id: "f-volunteer",
                title: "Volunteer Recruitment",
                summary: "Volunteers are won one ask at a time. Treat them like donors.",
                steps: [
                    DeepDiveStep(id: "f-1", title: "Recruitment funnel", body: "Sign-up → confirm shift → text day-of → show up → follow-up thanks. Skip a step, lose the volunteer.", exercise: nil),
                    DeepDiveStep(id: "f-2", title: "Volunteer leaders", body: "Identify reliable volunteers and give them ownership of turf or a shift. They become your force multipliers.", exercise: "Name three volunteers you'll promote to neighborhood leaders this month."),
                ]
            ),
            SubTopic(
                id: "f-turf",
                title: "Turf Cutting",
                summary: "Don't knock the universe; knock the right universe.",
                steps: [
                    DeepDiveStep(id: "f-3", title: "Prioritization", body: "Sort precincts by persuasion + turnout potential. Hit the top deciles first; backfill in GOTV week.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "f-gotv",
                title: "GOTV Plan",
                summary: "The four-day push that wins close races.",
                steps: [
                    DeepDiveStep(id: "f-4", title: "GOTV calendar", body: "T-4: chase early/absentee. T-3 to T-1: knock and call hard 1s. Election Day: pull 1s and 2s, no persuasion.", exercise: "Sketch your four-day GOTV calendar with a body count target each day."),
                ]
            ),
        ],
        seedPrompt: "Help me build a volunteer recruitment plan starting from zero.",
        isComplianceModule: false
    )

    // MARK: - 5. Compliance Guardrails
    static let compliance = CampaignModule(
        id: "compliance",
        title: "Compliance Guardrails",
        tagline: "Don't lose the race in the filing cabinet.",
        symbol: "checkmark.shield.fill",
        accent: Color(hex: 0xc9a84c),
        blurb: "Stay on the right side of contribution limits, coordination rules, disclaimers, and reporting deadlines. Always verify with your treasurer or counsel.",
        topics: [
            SubTopic(
                id: "c-limits",
                title: "Contribution Limits",
                summary: "Per-donor caps vary by jurisdiction and donor type.",
                steps: [
                    DeepDiveStep(id: "c-1", title: "Federal vs. state", body: "Federal limits are set by the FEC and updated each cycle. State limits vary widely — some states have no limits, others cap at a few hundred dollars. Always check the most current chart for your jurisdiction.", exercise: nil),
                    DeepDiveStep(id: "c-2", title: "Donor types", body: "Individuals, PACs, party committees, candidate committees — each has different caps. Corporate contributions are restricted federally and in many states.", exercise: "Bookmark the current FEC chart and your Secretary of State campaign-finance page."),
                ]
            ),
            SubTopic(
                id: "c-coord",
                title: "Coordination Rules",
                summary: "When can you talk to outside groups? Often: never about strategy.",
                steps: [
                    DeepDiveStep(id: "c-3", title: "The bright line", body: "Coordinated communications with PACs or party committees can convert independent expenditures into illegal in-kind contributions. The safest posture: do not discuss ad strategy, polling, or timing with any IE group.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "c-reports",
                title: "Reporting & Deadlines",
                summary: "Miss a report and you're explaining it to a reporter, not your treasurer.",
                steps: [
                    DeepDiveStep(id: "c-4", title: "Calendar your filings", body: "Quarterly, pre-primary, pre-general, 48-hour notices. Put every deadline on a shared calendar with a 7-day, 3-day, and same-day reminder.", exercise: "Add your next three filing deadlines to your calendar today."),
                ]
            ),
        ],
        seedPrompt: "Walk me through the compliance basics I need to know for my race.",
        isComplianceModule: true
    )

    // MARK: - 6. Earned Media
    static let earnedMedia = CampaignModule(
        id: "earned-media",
        title: "Earned Media",
        tagline: "The press is a megaphone. Make it ring.",
        symbol: "newspaper.fill",
        accent: Color(hex: 0xff8c5a),
        blurb: "Pitch reporters, run a press conference, handle the interview, and turn a moment into momentum.",
        topics: [
            SubTopic(
                id: "em-pitch",
                title: "Pitching Reporters",
                summary: "Short, newsworthy, with a clear hook.",
                steps: [
                    DeepDiveStep(id: "em-1", title: "Build your press list", body: "Identify the 10 reporters who cover your race. Email + cell. Read everything they write before you pitch them.", exercise: "Build a list of 10 reporters this week."),
                    DeepDiveStep(id: "em-2", title: "The pitch email", body: "Subject line is the story. Three sentences max. Why it's news, why now, why you. Include a quote.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "em-press",
                title: "Press Events",
                summary: "Run a press conference that gets covered, not ignored.",
                steps: [
                    DeepDiveStep(id: "em-3", title: "Anatomy of a press event", body: "Strong visual. Tight statement (3–4 minutes). Two surrogates. Q&A capped at 5 minutes. End with a one-line story for the chyron.", exercise: nil),
                ]
            ),
            SubTopic(
                id: "em-interview",
                title: "Interview Prep",
                summary: "Stay on message. Bridge to your pillars. Never repeat the attack.",
                steps: [
                    DeepDiveStep(id: "em-4", title: "Murder boards", body: "Sit a friend down and have them ask the five hardest questions. Answer until you stop flinching.", exercise: "Schedule a 30-minute murder board this week."),
                ]
            ),
        ],
        seedPrompt: "Help me write a pitch email to my local political reporter.",
        isComplianceModule: false
    )
}

/// Suggested daily focus surfaced on Home (F08).
enum DailyFocus {
    struct Focus: Hashable {
        let title: String
        let blurb: String
        let moduleId: String
        let topicId: String
    }

    static let weekly: [Focus] = [
        // Sunday
        Focus(title: "Plan the week", blurb: "Block call time, set door counts, write tomorrow's three goals.", moduleId: "field", topicId: "f-volunteer"),
        // Monday
        Focus(title: "Call time block", blurb: "90 minutes on the phone. No exceptions.", moduleId: "fundraising", topicId: "calltime"),
        // Tuesday
        Focus(title: "Tuesday call time", blurb: "Reactivate the maybes from last week. Get specific dollar commitments.", moduleId: "fundraising", topicId: "calltime"),
        // Wednesday
        Focus(title: "Doors after work", blurb: "Hit the door universe. Code every conversation 1–5.", moduleId: "voter-contact", topicId: "vc-canvass"),
        // Thursday
        Focus(title: "Message check", blurb: "Read your one sentence aloud. Tighten it before tonight's event.", moduleId: "messaging", topicId: "msg-core"),
        // Friday
        Focus(title: "Press pitch Friday", blurb: "Send three reporter pitches before noon.", moduleId: "earned-media", topicId: "em-pitch"),
        // Saturday
        Focus(title: "Volunteer canvass", blurb: "Lead a volunteer canvass shift. Recruit your next leader on the doors.", moduleId: "field", topicId: "f-volunteer"),
    ]

    static func today() -> Focus {
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sunday
        let idx = (weekday - 1 + weekly.count) % weekly.count
        return weekly[idx]
    }
}
