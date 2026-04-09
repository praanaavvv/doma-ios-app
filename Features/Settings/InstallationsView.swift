import SwiftUI

struct InstallationsView: View {
    @EnvironmentObject private var xmtp: XmtpService
    @Environment(\.dismiss) private var dismiss
    
    @State private var installations: [XmtpService.XMTPDevice] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isRevoking = false

    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Fetching devices...")
                            .padding()
                        Spacer()
                    }
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                } else if installations.isEmpty {
                    Text("No connected devices found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(installations, id: \.self) { info in
                        let isCurrent = info.id == xmtp.currentInstallationId
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Device ID")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if isCurrent {
                                    Text("This Device")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(info.id)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Text("Connected on \(info.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isCurrent {
                                Button(role: .destructive) {
                                    Task { await revokeSingle(info.id) }
                                } label: {
                                    Label("Revoke", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Active Devices")
            } footer: {
                Text("Swipe left on a device to revoke its access. You cannot revoke your current device.")
            }
        }
        .navigationTitle("XMTP Devices")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .overlay {
            if isRevoking {
                Color.black.opacity(0.2).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text("Closing session...")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let devices = try await xmtp.getInstallationDevices()
            self.installations = devices.sorted(by: { $0.createdAt > $1.createdAt }) // Newest first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func revokeSingle(_ id: String) async {
        isRevoking = true
        do {
            // It's cleaner to add a helper method in XmtpService to revoke by ID.
            try await xmtp.revokeInstallationByID(id)
            await loadData() // Refresh list
        } catch {
            errorMessage = "Failed to revoke: \(error.localizedDescription)"
        }
        isRevoking = false
    }
}
