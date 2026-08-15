import ZamClipCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchManager: LaunchManager
    @ObservedObject var store: ClipboardStore

    @State private var newBundleID = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section("General") {
                Toggle(
                    "Start at login",
                    isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    )
                )

                Picker(
                    "History limit",
                    selection: Binding(
                        get: { settings.historyLimit },
                        set: {
                            settings.historyLimit = $0
                            store.updateHistoryLimit($0)
                        }
                    )
                ) {
                    Text("100 items").tag(100)
                    Text("500 items").tag(500)
                    Text("1,000 items").tag(1000)
                    Text("2,000 items").tag(2000)
                }
            }

            Section("Privacy") {
                Toggle("Ignore unknown source apps", isOn: $settings.ignoreUnknownSources)

                HStack {
                    TextField("Bundle ID", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        settings.addExcludedBundleID(newBundleID)
                        newBundleID = ""
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                List {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                settings.removeExcludedBundleID(bundleID)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 90, maxHeight: 130)
            }

            Section("Storage") {
                Button("Clear Unpinned Items", role: .destructive) {
                    showingClearConfirmation = true
                }
            }

            if let error = launchManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 500, height: 430)
        .alert("Clear unpinned items?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) { store.clearUnpinned() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items will remain.")
        }
    }
}
