//
//  DomainCardRow.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 26/12/25.
//

import SwiftUI

struct DomainCardRow: View {
    let domain: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(domain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isSelected ? "Active for messaging" : "Tap to switch")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }

            Button {
                onSelect()
            } label: {
                Text(isSelected ? "Selected" : "Use this domain")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSelected ? Color.blue.opacity(0.18) : Color.blue)
                    .foregroundStyle(isSelected ? .blue : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
