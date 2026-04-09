import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var session: AppSession
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var analytics: DomaAPI.DomainAnalyticsResponse?
    
    var body: some View {
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

                if let domain = session.activeDomain {
                    Text(domain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView("Loading Analytics...")
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if let data = analytics {
                    // Two small cards row
                    HStack(spacing: 12) {
                        SmallStatCard(
                            icon: "bubble.left.and.bubble.right",
                            title: "Total Messages",
                            value: "\(data.totalMessages)",
                            pillText: "\(data.percentChange >= 0 ? "+" : "")\(String(format: "%.1f", data.percentChange))%",
                            pillIsGreen: data.percentChange >= 0
                        )

                        SmallStatCard(
                            icon: "chart.bar",
                            title: "Engagement Rate",
                            value: "\(String(format: "%.1f", data.engagementRate))%",
                            pillText: "Last 7 Days",
                            pillIsGreen: false
                        )
                    }
                    .padding(.horizontal, 16)

                    // Heatmap
                    HeatmapCard(heatmapData: data.heatmap)
                        .padding(.horizontal, 16)
                } else {
                    Text("No analytics available.")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }

                Spacer(minLength: 18)
            }
            .padding(.bottom, 22)
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await loadAnalytics() }
        }
    }
    
    private func loadAnalytics() async {
        guard let domain = session.activeDomain, !domain.isEmpty else {
            errorMessage = "No active domain selected."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await DomaAPI.shared.getDomainAnalytics(domain: domain)
            
            // Debug print to console
            print("[\(domain)] Analytics Response: \(data)")
            
            await MainActor.run {
                self.analytics = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
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
    let heatmapData: [DomaAPI.AnalyticsHeatmapDay]
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // Convert backend heatmap to max values for opacity scaling
    private var maxActivity: Double {
        let max = heatmapData.flatMap { $0.hours }.max() ?? 1
        return Double(max == 0 ? 1 : max)
    }

    private func color(for count: Int) -> Color {
        guard count > 0 else { return Color.primary.opacity(0.05) }
        let ratio = Double(count) / maxActivity
        switch ratio {
        case 0..<0.25:  return Color.blue.opacity(0.3)
        case 0.25..<0.5: return Color.blue.opacity(0.6)
        case 0.5..<0.75: return Color.blue.opacity(0.8)
        default:         return Color.blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Heatmap")
                .font(.system(size: 14, weight: .semibold))

            // heatmap grid (columns = days, rows = condensed hours)
            HStack(spacing: 8) {
                ForEach(0..<min(7, heatmapData.count), id: \.self) { dayIndex in
                    let dayData = heatmapData[dayIndex]
                    let condensed = condenseHours(dayData.hours, into: 7)
                    
                    VStack(spacing: 8) {
                        ForEach(0..<condensed.count, id: \.self) { row in
                            let count = condensed[row]
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color(for: count))
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
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    // Helper to condense 24 hours into fewer blocks (e.g., 7 columns)
    private func condenseHours(_ hours: [Int], into columns: Int) -> [Int] {
        guard hours.count > 0, columns > 0 else { return Array(repeating: 0, count: columns) }
        var result = [Int]()
        let chunkSize = Double(hours.count) / Double(columns)
        
        for i in 0..<columns {
            let start = Int(Double(i) * chunkSize)
            let end = min(Int(Double(i + 1) * chunkSize), hours.count)
            let chunkSum = hours[start..<end].reduce(0, +)
            result.append(chunkSum)
        }
        return result
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

