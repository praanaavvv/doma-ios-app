//
//  ConfigureDNSView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//

import SwiftUI

struct ConfigureDNSView: View {
    @EnvironmentObject private var session: AppSession
    @State private var isOnboarding = false
    @State private var onboardError: String?
    @State private var onboardSuccess = false

    let domain: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Configure DNS")
                    .font(.system(size: 22, weight: .bold))

                Text("Add these DNS records to enable messaging for \(domain).")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                DNSCard(title: "TXT Record", rows: [
                    ("Host", "@"),
                    ("Value", "doma-messaging=enabled"),
                ])

                DNSCard(title: "CNAME Record", rows: [
                    ("Host", "chat"),
                    ("Value", "messaging.doma.app"),
                ])

                if let err = onboardError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                if onboardSuccess {
                    Text("Messaging enabled for \(domain)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }

                Spacer().frame(height: 10)

                PrimaryWideButton(title: "Copy All Records") { }

                Button {
                    Task { await onboard() }
                } label: {
                    Text(onboardSuccess ? "Configured" : (isOnboarding ? "Configuring…" : "I’ve Added These Records"))
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isOnboarding || onboardSuccess)
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Configure")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func onboard() async {
        guard let owner = session.walletAddress, !owner.isEmpty else {
            await MainActor.run { self.onboardError = "Connect wallet before configuring." }
            return
        }
        await MainActor.run { self.isOnboarding = true; self.onboardError = nil }
        defer { Task { await MainActor.run { self.isOnboarding = false } } }
        do {
            try await DomaAPI.shared.onboardDomain(domain: domain, owner: owner, messagingEnabled: true, consentMode: "auto_accept", feeMode: "none")
            await MainActor.run { self.onboardSuccess = true }
        } catch {
            await MainActor.run { self.onboardError = error.localizedDescription }
        }
    }
}

private struct DNSCard: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Copy") { }
                    .font(.system(size: 13, weight: .semibold))
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).font(.system(size: 13)).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1).font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 6)

                Divider()
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
