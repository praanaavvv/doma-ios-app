//
//  DomainPickerView.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//

import SwiftUI

struct DomainPickerView: View {
    let domains: [String]
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            OrbitHeaderView()
                .frame(height: 320)
                .padding(.top, 12)
                .padding(.bottom, 16)

            Text("Multiple Domains Found!")
                .font(.system(size: 26, weight: .bold))

            Text("This wallet is associated with multiple domains, please select one domain to proceed to chats.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            VStack(spacing: 10) {
                ForEach(domains, id: \.self) { domain in
                    Button { onPick(domain) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe").foregroundStyle(.secondary)
                            Text(domain).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
