import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Top bar (avatar left, centered title)
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 34, height: 34)
                            .overlay(Text("🦁"))

                        Spacer()

                        Text("Analytics")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        // keep symmetry (invisible)
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 34, height: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // Wallet card
                    WalletRevenueCard()
                        .padding(.horizontal, 16)

                    // Two small cards row
                    HStack(spacing: 12) {
                        SmallStatCard(
                            icon: "bubble.left.and.bubble.right",
                            title: "Total Messages",
                            value: "1,248",
                            pillText: "+12%"
                        )

                        SmallStatCard(
                            icon: "chart.bar",
                            title: "Engagement Rate",
                            value: "88%",
                            pillText: "Last 7 Days",
                            pillIsGreen: false
                        )
                    }
                    .padding(.horizontal, 16)

                    // Heatmap
                    HeatmapCard()
                        .padding(.horizontal, 16)

                    Spacer(minLength: 18)
                }
                .padding(.bottom, 22)
            }
        }
    }
}

private struct WalletRevenueCard: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var dynamic: DynamicManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top) {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "bitcoinsign.circle")
                            .foregroundStyle(.secondary)
                    )

                Spacer()

                Pill(text: "Last 7 Days", isGreen: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("0.45 ETH")
                        .font(.system(size: 20, weight: .bold))

                    Text("($200.89)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Premium Revenue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            PrimaryWideButton(title: "Withdraw Wallet") {
                dynamic.disconnect()
                session.isAuthed = false
                session.walletAddress = nil
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct SmallStatCard: View {
    let icon: String
    let title: String
    let value: String
    let pillText: String
    var pillIsGreen: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(.secondary)
                    )

                Spacer()

                Pill(text: pillText, isGreen: pillIsGreen)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct HeatmapCard: View {
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // simple fixed pattern (UI-only)
    private let cells: [Double] = [
        0.9, 0.3, 0.1, 0.6, 0.2, 0.8, 0.4,
        0.2, 0.1, 0.7, 0.2, 0.3, 0.5, 0.1,
        0.6, 0.2, 0.1, 0.9, 0.2, 0.1, 0.7
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Heatmap")
                .font(.system(size: 14, weight: .semibold))

            // heatmap grid
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.15 + (cells[idx] * 0.75)))
                                .frame(height: 10)
                        }
                    }
                }
            }

            // day labels
            HStack {
                ForEach(days, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct Pill: View {
    let text: String
    let isGreen: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isGreen ? Color.green : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(Capsule())
    }
}

