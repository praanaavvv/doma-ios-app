//
//  DomainSwitchSheet.swift
//  DomaSecure
//
//  Created by Pranav Agarwal on 26/12/25.
//

import SwiftUI

struct DomainSwitchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let domains: [String]
    let selected: String?
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(domains, id: \.self) { d in
                    Button {
                        onPick(d)
                        dismiss()
                    } label: {
                        HStack {
                            Text(d)
                            Spacer()
                            if d == selected {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Switch Domain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
