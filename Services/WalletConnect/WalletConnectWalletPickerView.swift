import SwiftUI

struct WalletConnectWalletPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var wallet: WalletConnectManager

    var body: some View {
        NavigationStack {
            List {
                Section("Choose a wallet") {
                    ForEach(Wallet.all) { w in
                        Button {
                            dismiss()
                            wallet.connect(using: w)
                        } label: {
                            HStack {
                                Text(w.name)
                                Spacer()
                                if w.name == "MetaMask" {
                                    Text("Recommended")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(wallet.isConnecting)
                    }
                }

                if wallet.isConnecting {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Waiting for wallet approval…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let err = wallet.errorMessage {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
