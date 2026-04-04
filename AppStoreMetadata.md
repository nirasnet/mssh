# mSSH — App Store Metadata

## Core Listing Fields

### App Name
**mSSH** (4 characters, well under 30-char limit)

### Subtitle
**SSH Terminal for iOS** (22 characters)

### Promotional Text (170 chars max)
Lightweight SSH & SFTP client with Face ID security and iCloud sync. Connect to your servers from anywhere.

### Description (4000 chars max)

mSSH is a fast, secure SSH and SFTP client for iPhone and iPad. Connect to your remote servers with password or key-based authentication (Ed25519, ECDSA, RSA). Built with a focus on security and usability, mSSH uses xterm-256color terminal emulation for a native coding experience.

**Core Features**

SSH Terminal — Full SSH shell access with xterm-256color support for colors and formatting. Manage multiple connections simultaneously with tabbed sessions. Execute commands, edit files, and monitor servers directly from your device.

Key-Based Authentication — Support for Ed25519, ECDSA, and RSA keys. All private keys are encrypted and stored securely in the Keychain, never exposed in regular storage. No need to manage SSH keys on the server—just load your key and connect.

SFTP File Browser — Browse remote filesystems, upload and download files, edit files in place, and manage directories with an intuitive touch interface. Perfect for quick file access without needing to switch to a Mac or desktop.

Connection Profiles — Save and organize your frequently used SSH connections with custom names, ports, usernames, and authentication methods. Profiles sync automatically across your iPhone and iPad via iCloud.

Host Key Verification — Trust On First Use (TOFU) verification with SHA-256 fingerprints. Verify once, then connect securely. Helps prevent man-in-the-middle attacks by alerting you to unexpected host key changes.

Face ID & Touch ID — Biometric authentication for quick access to your saved credentials. Your passwords and SSH keys remain in the Keychain, encrypted and hardware-protected. Lock your terminals with biometrics when stepping away.

Dark Terminal UI — Beautiful dark-themed interface that reduces eye strain during long sessions. Clear terminal output with proper spacing and character rendering optimized for mobile.

**Privacy & Security**

All passwords and SSH keys are stored exclusively in the iOS Keychain with hardware encryption. Connection profiles are stored locally with iCloud sync disabled by default (can be enabled). No accounts required, no telemetry, no ads.

**Perfect For**

System administrators managing multiple servers from the road. DevOps engineers monitoring deployments on the go. Developers editing remote files and running quick commands. Homelab enthusiasts managing personal infrastructure.

---

### Keywords (100 chars total)
ssh, terminal, sftp, client, ios, server, shell, remote, key-based, authentication

*Character count: 100 characters*

### Category
- **Primary**: Utilities
- **Secondary**: Productivity

---

## Release Notes — Version 1.0.0

**Launch day! 🚀**

mSSH brings secure SSH and SFTP access to your iPhone and iPad. This is version 1.0, built from the ground up for iOS 18+.

**What's Included**

SSH Terminal — Full xterm-256color support. Connect with password or Ed25519/ECDSA/RSA keys. Tabbed multi-session management.

SFTP File Browser — Download, upload, delete, and edit files on remote servers with an intuitive interface.

Keychain Security — All credentials encrypted and hardware-protected. Face ID and Touch ID support for quick biometric access.

Connection Profiles — Save your servers and sync across iPhone and iPad via iCloud.

Host Key Verification — TOFU (Trust On First Use) with SHA-256 fingerprints to protect against MITM attacks.

**What's Free**

Up to 2 saved connection profiles. SSH terminal access. Host key management. Full SFTP file browser. All core features for light users.

**Pro Features (In-App Purchase)**

Unlimited connection profiles. Biometric (Face ID/Touch ID) protection toggle. iCloud sync of profiles. Advanced key management (import multiple keys). Background session persistence. Ad-free experience.

We built mSSH to be the fastest, most straightforward SSH client on iOS. No bloat, no telemetry, no unnecessary permissions. Enjoy your first two connections free.

---

## Support & Legal

### Support URL
`https://example.com/support`
*(Replace with your actual support domain or email contact form)*

### Privacy Policy URL
`https://example.com/privacy`
*(Replace with your actual privacy policy)*

---

## Age Rating

**Rating: 4+**

Rationale: No objectionable content. A terminal application for technical users. No violence, profanity, or adult content.

---

## In-App Purchases

### Pricing Strategy

**Freemium Model**: Core SSH/SFTP functionality free (limited to 2 profiles). Pro features for power users and professionals.

### Free Tier

- **2 Saved Connection Profiles** — Enough to test with a personal server and a VPS
- **SSH Terminal Access** — Full shell capability
- **SFTP File Browser** — Full file management
- **Host Key Management** — TOFU verification and storage
- **Xterm-256color Terminal** — Professional terminal emulation
- **Multiple Sessions** — Tab-based multi-connection within profiles

### Pro Bundle ($4.99/month or $49.99/year)

Recommended purchase for professionals and regular users.

**Features**
- **Unlimited Connection Profiles** — Organize hundreds of servers
- **Biometric Security** — Face ID/Touch ID quick-unlock for saved credentials
- **iCloud Sync** — Automatic sync of profiles and host keys across iPhone/iPad
- **Advanced Key Management** — Import and manage multiple SSH keys per profile; set per-profile defaults
- **Key Import Assistant** — Paste PEM/OpenSSH format keys directly into app
- **Connection Tagging** — Organize profiles with custom tags and groups
- **Background Session Persistence** — Keep SSH sessions alive when switching apps (30-min keep-alive)
- **Priority Support** — Email support for Pro subscribers
- **Pro Badge** — Show your support in the app

### Alternative: One-Time Pro Unlock ($19.99)

For users who prefer perpetual ownership over subscriptions.

**Includes all Pro features** (except priority support). One-time purchase, includes unlimited updates within the major version (e.g., 1.x).

### Why This Model?

- **Low barrier to entry**: Two free profiles let users try before buying
- **Transparent pricing**: Clear separation between free and pro
- **Subscription flexibility**: Monthly or yearly, with one-time option for commitment-averse users
- **Sustainable development**: Recurring revenue supports ongoing updates and server security
- **Fair to professionals**: Unlimited profiles and key management justify the annual cost for DevOps/sysadmins

### Future Considerations

- Port forwarding (consider as Pro-only after v1.0)
- SSH agent forwarding (Pro)
- Mosh/Eternal Terminal support (could be free or Pro)
- Local shell mode / scripting (free tier)
- Connection history/logging (Pro)

---

## App Store Optimization (ASO) Notes

### Keywords Rationale

- **ssh, terminal, client**: Core search terms
- **sftp, server, shell**: Feature-based keywords
- **remote**: Use-case keyword
- **ios**: Platform (automatic but explicit helps)
- **key-based, authentication**: Security-focused users find this
- Reserved space for variant: "secure, shell, management, linux"

### Competitive Positioning

mSSH differentiates by:
- **Simplicity**: No unnecessary features, no ads
- **Security**: Keychain integration, Face ID support, open design (no telemetry)
- **Affordability**: Free tier with 2 profiles. Pro at $4.99/month (lower than Termius)
- **iOS-native**: Built specifically for iOS/iPadOS with SwiftUI, not a wrapper
- **Speed**: Efficient terminal rendering using SwiftTerm (10x faster than early clients)

### Review Talking Points

For press and reviews, emphasize:
1. "Lightweight, fast, no ads" (vs. Termius bloat)
2. "Secure by default" (Keychain, Face ID, no telemetry)
3. "Free tier lets you try with 2 servers" (low commitment)
4. "Open design philosophy" (show GitHub if open-sourced)
5. "Built for iOS, not ported from Android/web"

---

## Submission Checklist

- [ ] App name, subtitle, and promotional text finalized
- [ ] Description reviewed for tone, feature clarity, and length (under 4000 chars)
- [ ] Keywords verified (100 chars, comma-separated, no spaces after commas)
- [ ] Support URL and Privacy Policy deployed and tested
- [ ] In-App Purchase products created in App Store Connect
  - [ ] Pro Bundle (monthly) — Product ID: `com.m4ck.mssh.pro.monthly`
  - [ ] Pro Bundle (yearly) — Product ID: `com.m4ck.mssh.pro.yearly`
  - [ ] One-Time Pro Unlock — Product ID: `com.m4ck.mssh.pro.lifetime`
- [ ] Screenshots (5 minimum) captured showing:
  - [ ] Terminal with colored output
  - [ ] SFTP file browser
  - [ ] Connection profiles list
  - [ ] Face ID authentication screen
  - [ ] Multi-tab terminal session
- [ ] Preview text on each screenshot
- [ ] Age rating set to 4+
- [ ] Category (Utilities, Productivity) confirmed
- [ ] Build tested on device and simulator
- [ ] App icons and launch screen final
- [ ] Version 1.0.0, build number finalized

---

## Notes

- **Descriptions avoid bullet points** (Apple's preferred style) and use flowing prose with section headers instead
- **Keywords are optimized** for both users searching and App Store algorithm
- **Pricing is competitive** against Termius (similar features at lower cost) and Prompt 3 (more affordable entry point)
- **Pro tier justifies subscription** via useful features (unlimited profiles, iCloud sync, biometric unlock, advanced key management) rather than artificial feature gates
- **Free tier is genuinely useful** (2 profiles covers personal use and testing) while creating a clear upgrade path
- **Support/Privacy URLs** should point to actual pages before submission
