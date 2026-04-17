# mSSH v1.2.0 — Release Notes for App Store Connect

## What's New in Version 1.2.0

Major renovation bringing Termius-level features to mSSH — a professional SSH client for iPhone, iPad, and Mac.

**Cross-Device Sync**
Your connections, SSH keys, and snippets now sync across iPhone, iPad, and Mac via iCloud. Private keys sync optionally through end-to-end encrypted iCloud Keychain — toggle per key from the Keys tab. Mac imports your existing ~/.ssh folder automatically on first launch.

**Terminal Themes & Customization**
Six built-in terminal themes (Default, Solarized Dark, Monokai, Nord, Dracula, Tokyo Night). Choose your font family, size (9–24pt), cursor style (block/bar/underline), and blink preference. All settings persist and apply instantly.

**Connection Organization**
Star your favorite connections to pin them at the top. Organize with groups (Production, Personal, etc.) and color tags. Search across all connections by name, host, or group. Swipe actions for quick edit and delete.

**Snippets (Saved Commands)**
Save frequently-used commands and send them to any active session with one tap. Access from the terminal toolbar or the iOS keyboard accessory bar. Usage stats track your most-used snippets.

**Port Forwarding (Preview)**
Configure local port-forwarding rules per connection profile. Rules are saved and ready to activate when the SSH library adds direct-tcpip support in a future update.

**Smarter Key Management**
Rename keys, toggle iCloud sync per key, and convert RSA keys to OpenSSH format for modern server compatibility. The app now detects when a key is missing on the current device and tells you exactly how to fix it — no more cryptic "authentication failed" errors.

**Settings Overhaul**
Reorganized into clear sections: Appearance, Terminal, Security, Sync, SSH, Data, and About. Live theme previews, font size stepper, and real-time sync status with your iCloud account.

**Bug Fixes**
- Connection test now uses real TCP probing instead of HTTP (which always failed on SSH ports)
- Terminal tab shows immediate feedback while connecting — spinner during handshake, clear error banner with Retry/Close on failure
- Fixed: editing a connection sometimes opened a blank "New Connection" form
- Fixed: error messages from key-parse failures and auth pre-flight checks now surface immediately instead of being hidden behind generic server responses

---

## Updated Promotional Text (170 chars)

Professional SSH & SFTP client with terminal themes, snippets, iCloud sync across iPhone, iPad & Mac. Free, no ads.

## Updated Subtitle

SSH & SFTP for iPhone, iPad, Mac

## Updated Keywords (100 chars)

ssh,terminal,sftp,client,server,shell,remote,key,sync,icloud,snippets,theme,mac

## Updated Description (4000 chars max)

mSSH is a professional SSH and SFTP client for iPhone, iPad, and Mac. Connect to your remote servers with password or key-based authentication (Ed25519, ECDSA, RSA). Six terminal themes, saved command snippets, and cross-device iCloud sync — everything you need to manage servers on the go.

**Cross-Device Sync**

Your connections, SSH keys, snippets, and settings sync across all your devices via iCloud. Private SSH keys are optionally synced through end-to-end encrypted iCloud Keychain — Apple cannot read them. On Mac, your existing ~/.ssh folder is imported automatically.

**Terminal Themes & Fonts**

Choose from six built-in themes: Default, Solarized Dark, Monokai, Nord, Dracula, and Tokyo Night. Pick your preferred font family and size (9–24pt), cursor style (block, bar, or underline), and blink behavior. Changes apply instantly to active sessions.

**Snippets**

Save commands you run often (deploy scripts, log tailing, service restarts) and send them to any active session with one tap. Access snippets from the terminal toolbar or the iOS keyboard accessory bar.

**Connection Organization**

Star favorites to pin them at the top. Group connections by environment (Production, Staging, Personal). Add color tags for visual scanning. Search across all connections by name, host, username, or group.

**SSH Terminal**

Full shell access with xterm-256color support. Manage multiple sessions with tabs. Split terminal view on iPad. Custom keyboard accessory bar with Esc, Tab, Ctrl, arrow keys, and quick-access snippets.

**Key-Based Authentication**

Support for Ed25519, ECDSA, and RSA keys in OpenSSH format. Generate Ed25519 keys directly in the app. Import keys by pasting PEM text or from your Mac's ~/.ssh folder. All private keys are stored in the iOS/macOS Keychain with hardware encryption.

**SFTP File Browser**

Browse remote filesystems, upload and download files, and manage directories. No persistent connections — each operation runs cleanly.

**Security**

Face ID and Touch ID for app-level protection. All credentials in the Keychain, hardware-encrypted. Host key verification via Trust On First Use (TOFU) with SHA-256 fingerprints. No accounts, no telemetry, no ads.

**Mac Support**

Native macOS app with sidebar navigation. Import your ~/.ssh keys and config with one click. Sync connections from iPhone via iCloud.

**Open Source**

mSSH is open source at github.com/nirasnet/mssh. Built with SwiftTerm (terminal emulation) and Citadel (SSH2 protocol).
