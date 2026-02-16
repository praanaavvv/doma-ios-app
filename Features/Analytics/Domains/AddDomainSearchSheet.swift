//
//  AddDomainSearchSheet.swift
//  DomaSecure
//

import SwiftUI

struct AddDomainSearchSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            SearchSheetView()
                .navigationTitle("Add new domain")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

#Preview {
    AddDomainSearchSheet(isPresented: .constant(true))
}

