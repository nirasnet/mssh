# mSSH Marketing Kit

## Taglines (pick your favorite)

- "SSH from your pocket. Open source, no ads, just works."
- "The SSH client Termius should have been — free, open source, syncs everywhere."
- "Professional SSH for iPhone, iPad & Mac. Zero telemetry. 100% open source."
- "Your servers, your keys, your device. No cloud accounts required."

---

## Product Hunt Launch

**Title:** mSSH — Open source SSH & SFTP client for iPhone, iPad & Mac

**Tagline:** Professional SSH with terminal themes, snippets, and iCloud sync. Free, no ads.

**Description:**

Hey Product Hunt! I built mSSH because I needed a fast, private SSH client that works across all my Apple devices without requiring a cloud account or subscription.

What makes mSSH different:

- **Completely free & open source** — no freemium gates, no subscription, no ads. Tip jar if you want to support development.
- **Cross-device sync** — connections, keys, and snippets sync across iPhone, iPad, and Mac via iCloud. Private keys use end-to-end encrypted iCloud Keychain.
- **6 terminal themes** — Default, Solarized Dark, Monokai, Nord, Dracula, Tokyo Night. Plus customizable fonts, cursor style, and size.
- **Snippets** — save your most-used commands, send them with one tap
- **Mac ~/.ssh import** — first launch imports your existing keys and SSH config automatically
- **Privacy-first** — no accounts, no telemetry, all credentials in the hardware-encrypted Keychain

Built with SwiftUI, SwiftTerm, and Citadel. The entire codebase is on GitHub.

GitHub: https://github.com/nirasnet/mssh
App Store: [link]

---

## Reddit Posts

### r/selfhosted

**Title:** I built an open-source SSH client for iOS/Mac that syncs across devices — no account required

Just shipped mSSH v1.2.0 — a free, open-source SSH & SFTP client for iPhone, iPad, and Mac.

I built it because every SSH app either wants a monthly subscription, requires a cloud account, or phones home with telemetry. mSSH uses your existing iCloud for sync (optional) and stores everything in the Keychain. No accounts, no analytics, no ads.

Features that might interest this community:
- Import your existing ~/.ssh keys + config on Mac automatically
- 6 terminal themes (Solarized, Dracula, Nord, Monokai, Tokyo Night)
- Saved command snippets with one-tap send
- Connection organization (favorites, groups, color tags, search)
- Face ID / Touch ID lock
- SFTP file browser

It's MIT licensed: https://github.com/nirasnet/mssh

Free on the App Store — there's a tip jar if you find it useful, but everything works without paying.

Feedback welcome — especially from fellow homelab people.

### r/iOSProgramming

**Title:** Open-sourced my SSH client — SwiftUI + SwiftData + CloudKit + SwiftTerm + Citadel

Just open-sourced mSSH, an SSH/SFTP client for iOS and macOS. Some interesting technical bits if you're into SwiftUI:

- **SwiftTerm + Citadel bridging** — two incompatible async paradigms (NIO event loops vs UIKit delegates) connected through an AsyncStream serialiser that prevents multi-byte input hangs
- **SwiftData + CloudKit** with a dual-store migration strategy for safe upgrades
- **NSUbiquitousKeyValueStore** as a CloudKit fallback for macOS (SwiftUI 26.3 has a layout crash with CloudKit notifications during NSHostingView sizing)
- **StoreKit 2** tip jar with a .storekit test configuration
- **DECSCUSR escape sequences** for portable cursor style control (SwiftTerm's Terminal property is internal on iOS)

The architecture is documented in detail in CLAUDE.md — useful if you want to understand how the pieces fit together.

GitHub: https://github.com/nirasnet/mssh

### r/apple

**Title:** Free, open-source SSH client for iPhone, iPad & Mac — no subscription, no ads

Built mSSH as a Termius alternative that doesn't require a subscription or cloud account. It's completely free, open source (MIT), and syncs across your devices via iCloud.

6 terminal themes, saved command snippets, SFTP, Face ID lock, and automatic Mac ~/.ssh import. Everything stores in the Keychain with hardware encryption. No telemetry.

App Store: [link]
Source: https://github.com/nirasnet/mssh

---

## Hacker News

**Title:** Show HN: mSSH – Open-source SSH client for iOS/Mac with iCloud sync

**Text:**

I've been building mSSH, a native SSH & SFTP client for iPhone, iPad, and Mac. It's free, MIT licensed, and has no telemetry.

I was frustrated with existing iOS SSH clients — Termius locks basic features behind a subscription, Prompt is expensive, and most alternatives feel abandoned. So I built what I wanted:

- Full xterm-256color terminal (SwiftTerm)
- SSH2 via Citadel (NIO-based)
- 6 themes, custom fonts, cursor styles
- Saved command snippets
- Connection organization (favorites, groups, tags, search)
- Cross-device sync via iCloud (no account signup)
- Mac auto-imports from ~/.ssh
- Face ID / Touch ID
- SFTP browser

Tech stack: Swift 5.9, SwiftUI, SwiftData + CloudKit, StoreKit 2 tip jar (everything free, tips optional).

Interesting technical challenges documented in CLAUDE.md: the SwiftTerm ↔ Citadel bridge uses an AsyncStream serialiser because NIO's pipeline isn't safe for concurrent callers (discovered via Thai UTF-8 input hanging the channel). Citadel's RSA implementation only does SHA-1 signatures, so modern OpenSSH 9.x servers reject RSA keys — users need Ed25519 instead.

Source: https://github.com/nirasnet/mssh
App Store: [link]

---

## Twitter/X Thread

**Tweet 1:**
Just shipped mSSH v1.2.0 — a free, open-source SSH client for iPhone, iPad & Mac.

No subscription. No ads. No telemetry. Just SSH.

6 themes, snippets, iCloud sync, SFTP, Face ID lock.

App Store: [link]
GitHub: github.com/nirasnet/mssh

🧵 Here's what makes it different ↓

**Tweet 2:**
Terminal themes that actually look good on mobile.

Default, Solarized Dark, Monokai, Nord, Dracula, Tokyo Night.

Custom font family, size (9-24pt), cursor style. Changes apply instantly to active sessions.

**Tweet 3:**
Cross-device sync without a cloud account.

Your connections, keys, and snippets sync across iPhone, iPad & Mac via iCloud. Private SSH keys use Apple's end-to-end encrypted Keychain.

On Mac, it auto-imports your ~/.ssh folder on first launch.

**Tweet 4:**
Snippets = saved commands you run constantly.

"docker ps", "tail -f /var/log/syslog", your deploy script — save once, one-tap send to any active session.

Access from the terminal toolbar or the iOS keyboard accessory bar.

**Tweet 5:**
It's MIT licensed, entirely on GitHub.

Built with SwiftTerm + Citadel. Architecture docs in CLAUDE.md if you want to contribute or learn.

There's a tip jar in Settings if you want to support development. But everything works without paying.

github.com/nirasnet/mssh

---

## Promotion Channels Checklist

### Free (do these first)
- [ ] **GitHub** — README is live, add topics: `ssh`, `terminal`, `ios`, `macos`, `swift`, `swiftui`, `sftp`
- [ ] **Product Hunt** — schedule launch for a Tuesday/Wednesday morning (best traffic)
- [ ] **Hacker News** — "Show HN" post (best on weekday mornings US time)
- [ ] **Reddit** — r/selfhosted, r/homelab, r/iOSProgramming, r/apple, r/commandline, r/sysadmin
- [ ] **Twitter/X** — thread format works best for dev tools
- [ ] **Mastodon** — post on fosstodon.org or similar tech instance
- [ ] **Dev.to** — write a "Building an SSH client in Swift" article
- [ ] **Lobste.rs** — submit with `show` tag
- [ ] **iOS Dev Weekly** — submit via their form (curated newsletter)
- [ ] **Swift Weekly Brief** — submit link

### Paid (if tips come in)
- [ ] **Setapp** — apply for inclusion (they take a rev share, not upfront)
- [ ] **Apple Search Ads** — bid on "ssh client", "terminal ios", "sftp iphone"
- [ ] **Carbon Ads** — developer-focused display ads
