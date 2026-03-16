//
//  Buttons.swift
//  DomaSecure
//

import SwiftUI

// MARK: - Pill Buttons (used on onboarding)

struct PrimaryPillButton: View {
    let title: String
    let systemIcon: String?
    let action: () -> Void

    init(title: String,
         systemIcon: String? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.systemIcon = systemIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let systemIcon {
                    Image(systemName: systemIcon)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryPillButton: View {
    let title: String
    let systemIcon: String?
    let action: () -> Void

    init(title: String,
         systemIcon: String? = nil,
         action: @escaping () -> Void) {
        self.title = title
        self.systemIcon = systemIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let systemIcon {
                    Image(systemName: systemIcon)
                }
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wide Buttons (for chat detail etc)

struct PrimaryWideButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryWideButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryPillButton(title: "Connect Wallet", systemIcon: "wallet.pass") {}
        SecondaryPillButton(title: "Continue", systemIcon: "g.circle") {}

        PrimaryWideButton(title: "Primary Wide", action: {})
        SecondaryWideButton(title: "Secondary Wide", action: {})
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

