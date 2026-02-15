//
//  VerifyAndSignView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//
import SwiftUI

struct VerifyAndSignView: View {
    let domain: String
    @State private var isVerified = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 20)

            Text("Verify & Sign")
                .font(.system(size: 22, weight: .bold))

            Text("We’ll verify your DNS records and sign to enable messaging for \(domain).")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                StatusRow(title: "DNS Records", ok: isVerified)
                StatusRow(title: "Domain Ownership", ok: isVerified)
                StatusRow(title: "Messaging Enabled", ok: isVerified)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)

            PrimaryWideButton(title: "Verify Now") {
                // UI-only: simulate success
                withAnimation(.easeInOut(duration: 0.2)) { isVerified = true }
            }
            .padding(.horizontal, 16)

            SecondaryWideButton(title: "Sign & Enable Messaging") { }
                .padding(.horizontal, 16)

            Spacer()
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatusRow: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .semibold))
            Spacer()
            Image(systemName: ok ? "checkmark.seal.fill" : "clock")
                .foregroundStyle(ok ? .blue : .secondary)
        }
        .padding(.vertical, 6)
    }
}

