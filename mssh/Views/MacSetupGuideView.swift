import SwiftUI

struct MacSetupGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    headerSection

                    // Step 1: Locate keys
                    stepSection(
                        number: 1,
                        title: "Locate Your SSH Keys",
                        description: "Your SSH keys are typically stored in the ~/.ssh directory on your Mac.",
                        commands: [
                            "ls -la ~/.ssh/"
                        ],
                        note: "You should see files like id_ed25519, id_rsa, or id_ecdsa (private keys) and their .pub counterparts (public keys)."
                    )

                    // Step 2: Create iCloud folder
                    stepSection(
                        number: 2,
                        title: "Create an iCloud Folder",
                        description: "Create a dedicated folder in iCloud Drive to share your keys with mSSH.",
                        commands: [
                            "mkdir -p ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys"
                        ],
                        note: nil
                    )

                    // Step 3: Copy keys
                    stepSection(
                        number: 3,
                        title: "Copy Your Keys",
                        description: "Copy the private key files you want to use on your iOS device. Replace the filenames with your actual key names.",
                        commands: [
                            "cp ~/.ssh/id_ed25519 ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys/",
                            "cp ~/.ssh/id_rsa ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys/"
                        ],
                        note: "Only copy the private keys (without .pub extension). mSSH will extract the public key information."
                    )

                    // Step 4: Copy SSH config (optional)
                    stepSection(
                        number: 4,
                        title: "Copy SSH Config (Optional)",
                        description: "If you want to import your saved connections, copy your SSH config file too.",
                        commands: [
                            "cp ~/.ssh/config ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys/"
                        ],
                        note: "This lets you import all your host aliases, usernames, and port settings at once."
                    )

                    // Step 5: One-liner
                    stepSection(
                        number: 5,
                        title: "One-Line Copy (All Keys + Config)",
                        description: "Or copy everything in one command:",
                        commands: [
                            "mkdir -p ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys && cp ~/.ssh/id_* ~/.ssh/config ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys/ 2>/dev/null"
                        ],
                        note: nil
                    )

                    // Security warnings
                    securitySection

                    // Step 6: Import in mSSH
                    importStepSection

                    // Cleanup
                    cleanupSection
                }
                .padding()
            }
            .navigationTitle("Mac Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            Text("How to Share Mac SSH Keys with mSSH")
                .font(.title2.bold())

            Text("Transfer your existing SSH keys from your Mac to mSSH using iCloud Drive. This guide walks you through each step.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Numbered Step

    private func stepSection(number: Int, title: String, description: String, commands: [String], note: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())

                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(commands, id: \.self) { command in
                    CommandBlock(command: command)
                }
            }
            .padding(.leading, 36)

            if let note = note {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 36)
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Security Considerations")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                warningItem("iCloud Drive files are encrypted in transit and at rest, but Apple holds the encryption keys unless you enable Advanced Data Protection.")
                warningItem("Delete the keys from iCloud Drive after importing them into mSSH. The app stores them securely in the iOS Keychain.")
                warningItem("Never share private keys via email, messaging apps, or unencrypted channels.")
                warningItem("Consider generating a dedicated key pair for your iOS device instead of sharing your Mac's keys.")
                warningItem("If your private key has a passphrase, you will need it during import. Passphrase-protected keys add an extra layer of security.")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }

    private func warningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Import Step

    private var importStepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("6")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())

                Text("Import in mSSH")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                instructionItem("1.", "Open mSSH and go to SSH Keys.")
                instructionItem("2.", "Tap the + button and select \"Import Wizard\".")
                instructionItem("3.", "Choose \"iCloud Drive\" as the source.")
                instructionItem("4.", "Navigate to the SSH-Keys folder and select your key files.")
                instructionItem("5.", "Preview the detected keys and confirm import.")
                instructionItem("6.", "Optionally, use \"Import SSH Config\" to bring in your saved connections.")
            }
            .padding(.leading, 36)
        }
    }

    private func instructionItem(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cleanup

    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("7")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())

                Text("Clean Up (Recommended)")
                    .font(.headline)
            }

            Text("After importing your keys, remove them from iCloud Drive for security:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 36)

            CommandBlock(command: "rm -rf ~/Library/Mobile\\ Documents/com~apple~CloudDocs/SSH-Keys")
                .padding(.leading, 36)
        }
    }
}

// MARK: - Command Block

private struct CommandBlock: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()

            Button {
                UIPasteboard.general.string = command
                withAnimation {
                    copied = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
