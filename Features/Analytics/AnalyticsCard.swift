//
//  AnalyticsCard.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//

import SwiftUI

struct AnalyticsCard: View {
    let title: String
    let value: String
    let trend: String?
    var wide: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))

            if let trend {
                Text(trend)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: wide ? .infinity : nil, minHeight: 86)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
