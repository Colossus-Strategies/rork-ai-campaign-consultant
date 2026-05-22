//
//  WalkPacketPDF.swift
//  AICampaignConsultant
//
//  Generates a printable, door-knock-ready PDF from a list of voters.
//  Grouped by precinct, with a header for the candidate / district and
//  a checkbox column for each row. Output is letter-size, 0.5" margins.
//

import UIKit
import CoreText

enum WalkPacketPDF {

    private static let pageSize = CGSize(width: 612, height: 792) // US Letter
    private static let margin: CGFloat = 36
    private static let rowHeight: CGFloat = 26

    /// Writes a PDF walk packet to a temporary file and returns the URL.
    static func render(profile: CandidateProfile, listName: String, rows: [VoterRow]) -> URL? {
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: pdfMetadata(profile: profile, listName: listName))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("walk-packet-\(Int(Date().timeIntervalSince1970)).pdf")

        let grouped = Dictionary(grouping: rows, by: { $0.precinct ?? "—" })
        let precincts = grouped.keys.sorted()

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()
                y = drawHeader(profile: profile, listName: listName, totalRows: rows.count, in: ctx, y: y)

                for precinct in precincts {
                    let voters = (grouped[precinct] ?? [])
                        .sorted { ($0.last_name ?? "") < ($1.last_name ?? "") }

                    if y + 60 > pageSize.height - margin {
                        ctx.beginPage()
                        y = margin
                    }
                    y = drawPrecinctHeader(precinct: precinct, count: voters.count, y: y)
                    y = drawColumnHeaders(y: y)

                    for (idx, voter) in voters.enumerated() {
                        if y + rowHeight > pageSize.height - margin {
                            ctx.beginPage()
                            y = margin
                            y = drawPrecinctHeader(precinct: precinct + " (cont.)", count: voters.count, y: y)
                            y = drawColumnHeaders(y: y)
                        }
                        drawRow(voter, index: idx, y: y)
                        y += rowHeight
                    }
                    y += 8
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Metadata

    private static func pdfMetadata(profile: CandidateProfile, listName: String) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Walk Packet — \(listName)",
            kCGPDFContextAuthor as String: profile.name,
            kCGPDFContextCreator as String: "Colossus Campaign Consultant"
        ]
        return format
    }

    // MARK: - Drawing helpers

    private static func drawHeader(profile: CandidateProfile, listName: String, totalRows: Int, in ctx: UIGraphicsPDFRendererContext, y startY: CGFloat) -> CGFloat {
        var y = startY
        let title = "WALK PACKET"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor(red: 0.78, green: 0.62, blue: 0.32, alpha: 1),
            .kern: 2.4
        ]
        (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 16

        let listAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        (listName as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: listAttrs)
        y += 26

        let race = profile.raceType.label
        let district = profile.district.isEmpty ? profile.state : profile.district
        let office = profile.office.isEmpty ? "" : " · \(profile.office)"
        let metaLines: [String] = [
            "\(profile.name) — \(race)\(office)",
            "District: \(district)" + (profile.location.isEmpty ? "" : "  ·  \(profile.location)"),
            "Voters: \(totalRows.formatted())  ·  Generated: \(Self.dateString())"
        ]
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        for line in metaLines {
            (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: metaAttrs)
            y += 14
        }
        y += 6
        let divider = CGRect(x: margin, y: y, width: pageSize.width - margin * 2, height: 0.6)
        UIColor(red: 0.78, green: 0.62, blue: 0.32, alpha: 1).setFill()
        UIRectFill(divider)
        y += 12
        return y
    }

    private static func drawPrecinctHeader(precinct: String, count: Int, y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let label = "PRECINCT \(precinct)  (\(count))"
        (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        return y + 18
    }

    private static func drawColumnHeaders(y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.gray,
            .kern: 1.0
        ]
        let xCols: [(String, CGFloat)] = [
            ("✓", margin),
            ("NAME", margin + 22),
            ("P", margin + 200),
            ("AGE", margin + 222),
            ("ADDRESS", margin + 258),
            ("SCORE", pageSize.width - margin - 42)
        ]
        for (text, x) in xCols {
            (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        }
        return y + 14
    }

    private static func drawRow(_ voter: VoterRow, index: Int, y: CGFloat) {
        if index % 2 == 1 {
            let bg = CGRect(x: margin - 2, y: y - 2, width: pageSize.width - margin * 2 + 4, height: rowHeight - 2)
            UIColor(white: 0.97, alpha: 1).setFill()
            UIRectFill(bg)
        }

        // Checkbox
        let box = CGRect(x: margin, y: y + 4, width: 12, height: 12)
        let path = UIBezierPath(rect: box)
        UIColor.darkGray.setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor(red: 0.78, green: 0.62, blue: 0.32, alpha: 1)
        ]

        let name = voter.fullName.isEmpty ? "—" : voter.fullName
        (name as NSString).draw(in: CGRect(x: margin + 22, y: y + 2, width: 180, height: 16),
                                withAttributes: nameAttrs)
        (voter.partyShort as NSString).draw(at: CGPoint(x: margin + 200, y: y + 3),
                                            withAttributes: bodyAttrs)
        let ageText = voter.age.map(String.init) ?? "—"
        (ageText as NSString).draw(at: CGPoint(x: margin + 222, y: y + 3),
                                   withAttributes: bodyAttrs)
        let address = [voter.address, voter.city, voter.zip]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")
        let addrWidth = pageSize.width - margin - 50 - (margin + 258)
        (address as NSString).draw(in: CGRect(x: margin + 258, y: y + 2, width: addrWidth, height: 16),
                                   withAttributes: bodyAttrs)
        let score = "\(voter.turnout_score ?? 0)/5"
        (score as NSString).draw(at: CGPoint(x: pageSize.width - margin - 38, y: y + 2),
                                 withAttributes: scoreAttrs)
    }

    private static func dateString() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
