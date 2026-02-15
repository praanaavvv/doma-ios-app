//
//  TimeRangePicker.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 21/12/25.
//
import SwiftUI

enum TimeRange: String, CaseIterable {
    case today = "Today"
    case week = "7d"
    case month = "30d"
}

struct TimeRangePicker: View {
    @Binding var selected: TimeRange

    var body: some View {
        HStack(spacing: 10) {
            ForEach(TimeRange.allCases, id: \.self) { r in
                Button {
                    selected = r
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected == r ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected == r ? Color.blue : Color(.systemGray6))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
