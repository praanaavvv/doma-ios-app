//
//  DomainDetailView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//

import SwiftUI

struct DomainDetailView: View {
    let domain: String
    let isConfigured: Bool

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 12)

            Circle().fill(Color(.systemGray5)).frame(width: 90, height: 90)

            Text(domain)
                .font(.system(size: 22, weight: .bold))

            Text(isConfigured ? "Messaging is configured for this domain." :
                 "Messaging is not configured yet. Configure DNS to enable messaging.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)

            NavigationLink {
                ConfigureDNSView(domain: domain)
            } label: {
                PrimaryWideButton(title: "Configure DNS") { }
            }
            .padding(.horizontal, 16)

            NavigationLink {
                VerifyAndSignView(domain: domain)
            } label: {
                SecondaryWideButton(title: "Verify & Sign") { }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .navigationTitle("Domain")
        .navigationBarTitleDisplayMode(.inline)
    }
}
