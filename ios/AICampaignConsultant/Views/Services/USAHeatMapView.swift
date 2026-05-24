//
//  USAHeatMapView.swift
//  AICampaignConsultant
//
//  Stylized statebin-grid heat map of the United States. Each cell is a
//  state square colored by an animated heat value. Used as the marquee
//  graphic for the District Intelligence service card.
//

import SwiftUI

struct USAHeatMapView: View {
    /// Pulse phase 0…1 used to animate intensity values across the map.
    @State private var phase: CGFloat = 0

    private static let cols: Int = 11
    private static let rows: Int = 8

    // Statebin layout (row, col, code, baseHeat 0-1).
    // Heat values are illustrative — meant to look like a real density map.
    private static let cells: [Cell] = [
        // Row 0
        Cell(0, 0, "AK", 0.20), Cell(0, 10, "ME", 0.30),
        // Row 1
        Cell(1, 9, "VT", 0.25), Cell(1, 10, "NH", 0.35),
        // Row 2
        Cell(2, 1, "WA", 0.75), Cell(2, 2, "ID", 0.30), Cell(2, 3, "MT", 0.25),
        Cell(2, 4, "ND", 0.20), Cell(2, 5, "MN", 0.60), Cell(2, 6, "WI", 0.70),
        Cell(2, 7, "MI", 0.80), Cell(2, 9, "NY", 0.95), Cell(2, 10, "MA", 0.85),
        // Row 3
        Cell(3, 1, "OR", 0.55), Cell(3, 2, "UT", 0.45), Cell(3, 3, "WY", 0.20),
        Cell(3, 4, "SD", 0.25), Cell(3, 5, "IA", 0.55), Cell(3, 6, "IL", 0.85),
        Cell(3, 7, "IN", 0.70), Cell(3, 8, "OH", 0.90), Cell(3, 9, "PA", 0.92),
        Cell(3, 10, "CT", 0.65),
        // Row 4
        Cell(4, 1, "CA", 1.00), Cell(4, 2, "NV", 0.55), Cell(4, 3, "CO", 0.70),
        Cell(4, 4, "NE", 0.35), Cell(4, 5, "MO", 0.65), Cell(4, 6, "KY", 0.55),
        Cell(4, 7, "WV", 0.45), Cell(4, 8, "VA", 0.80), Cell(4, 9, "NJ", 0.85),
        Cell(4, 10, "RI", 0.45),
        // Row 5
        Cell(5, 2, "AZ", 0.75), Cell(5, 3, "NM", 0.45), Cell(5, 4, "KS", 0.40),
        Cell(5, 5, "AR", 0.50), Cell(5, 6, "TN", 0.70), Cell(5, 7, "NC", 0.85),
        Cell(5, 8, "SC", 0.60), Cell(5, 9, "DE", 0.40), Cell(5, 10, "MD", 0.70),
        // Row 6
        Cell(6, 0, "HI", 0.30), Cell(6, 4, "OK", 0.55), Cell(6, 5, "LA", 0.60),
        Cell(6, 6, "MS", 0.50), Cell(6, 7, "AL", 0.65), Cell(6, 8, "GA", 0.90),
        // Row 7
        Cell(7, 4, "TX", 1.00), Cell(7, 9, "FL", 0.95),
    ]

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(
                (geo.size.width - CGFloat(Self.cols + 1) * 4) / CGFloat(Self.cols),
                (geo.size.height - CGFloat(Self.rows + 1) * 4) / CGFloat(Self.rows)
            )
            let totalW = CGFloat(Self.cols) * cellSize + CGFloat(Self.cols - 1) * 4
            let totalH = CGFloat(Self.rows) * cellSize + CGFloat(Self.rows - 1) * 4
            let originX = (geo.size.width - totalW) / 2
            let originY = (geo.size.height - totalH) / 2

            ZStack {
                ForEach(Self.cells) { cell in
                    let heat = animatedHeat(for: cell)
                    let x = originX + CGFloat(cell.col) * (cellSize + 4)
                    let y = originY + CGFloat(cell.row) * (cellSize + 4)
                    RoundedRectangle(cornerRadius: cellSize * 0.18, style: .continuous)
                        .fill(heatColor(heat))
                        .overlay(
                            RoundedRectangle(cornerRadius: cellSize * 0.18, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                        .overlay(
                            Text(cell.code)
                                .font(.system(size: max(7, cellSize * 0.32), weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white.opacity(heat > 0.55 ? 0.95 : 0.55))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        )
                        .frame(width: cellSize, height: cellSize)
                        .position(x: x + cellSize / 2, y: y + cellSize / 2)
                        .shadow(color: heatColor(heat).opacity(heat * 0.55), radius: heat * 6)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func animatedHeat(for cell: Cell) -> CGFloat {
        // Drift each state's heat with a per-state phase offset so the map
        // shimmers without all cells pulsing in lockstep.
        let offset = CGFloat((cell.row * 7 + cell.col * 3) % 10) / 10
        let wave = sin((phase + offset) * .pi * 2) * 0.08
        return max(0, min(1, cell.heat + wave))
    }

    private func heatColor(_ h: CGFloat) -> Color {
        // Cold (deep navy) → mid (gold) → hot (crimson). All on-brand.
        if h < 0.5 {
            let t = h / 0.5
            return blend(
                Color(hex: 0x1a3a6e),
                Color(hex: 0xc9a84c),
                t: t
            )
        } else {
            let t = (h - 0.5) / 0.5
            return blend(
                Color(hex: 0xc9a84c),
                Color(hex: 0xd14a3b),
                t: t
            )
        }
    }

    private func blend(_ a: Color, _ b: Color, t: CGFloat) -> Color {
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar + (br - ar) * t),
            green: Double(ag + (bg - ag) * t),
            blue: Double(ab + (bb - ab) * t),
            opacity: Double(aa + (ba - aa) * t)
        )
    }

    private struct Cell: Identifiable {
        let id: String
        let row: Int
        let col: Int
        let code: String
        let heat: CGFloat
        init(_ row: Int, _ col: Int, _ code: String, _ heat: CGFloat) {
            self.id = code
            self.row = row
            self.col = col
            self.code = code
            self.heat = heat
        }
    }
}
