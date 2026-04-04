# mSSH — Quick Finish Guide

## What's Done

| Task | Status |
|------|--------|
| SSH connection fix (algorithm fallback) | Done |
| RSA key authentication fix | Done |
| App icon (1024x1024, no alpha) | Done |
| Build archived & uploaded to App Store Connect | Done (v1.0.0, build 1) |
| Privacy policy created & hosted | Done |
| App Store metadata prepared | Done |
| Screenshots created (5x) | Done |
| App record created in App Store Connect | Done |

---

## What You Need To Do (10 minutes)

### 1. Log into App Store Connect
Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **mssh**

### 2. Select Your Build
- Click on your app version **1.0.0**
- Under **Build**, click **+** and select the uploaded build (1.0.0, build 1)

### 3. Fill In Metadata

**Copy-paste these fields:**

#### Promotional Text (170 chars)
```
Lightweight SSH & SFTP client with Face ID security and iCloud sync. Connect to your servers from anywhere.
```

#### Description
```
mSSH is a fast, secure SSH and SFTP client for iPhone and iPad. Connect to your remote servers with password or key-based authentication (Ed25519, ECDSA, RSA). Built with a focus on security and usability, mSSH uses xterm-256color terminal emulation for a native coding experience.

Core Features

SSH Terminal — Full SSH shell access with xterm-256color support for colors and formatting. Manage multiple connections simultaneously with tabbed sessions. Execute commands, edit files, and monitor servers directly from your device.

Key-Based Authentication — Support for Ed25519, ECDSA, and RSA keys. All private keys are encrypted and stored securely in the Keychain, never exposed in regular storage. No need to manage SSH keys on the server—just load your key and connect.

SFTP File Browser — Browse remote filesystems, upload and download files, edit files in place, and manage directories with an intuitive touch interface. Perfect for quick file access without needing to switch to a Mac or desktop.

Connection Profiles — Save and organize your frequently used SSH connections with custom names, ports, usernames, and authentication methods. Profiles sync automatically across your iPhone and iPad via iCloud.

Host Key Verification — Trust On First Use (TOFU) verification with SHA-256 fingerprints. Verify once, then connect securely. Helps prevent man-in-the-middle attacks by alerting you to unexpected host key changes.

Face ID & Touch ID — Biometric authentication for quick access to your saved credentials. Your passwords and SSH keys remain in the Keychain, encrypted and hardware-protected. Lock your terminals with biometrics when stepping away.

Dark Terminal UI — Beautiful dark-themed interface that reduces eye strain during long sessions. Clear terminal output with proper spacing and character rendering optimized for mobile.

Privacy & Security

All passwords and SSH keys are stored exclusively in the iOS Keychain with hardware encryption. Connection profiles are stored locally with iCloud sync disabled by default (can be enabled). No accounts required, no telemetry, no ads.

Perfect For

System administrators managing multiple servers from the road. DevOps engineers monitoring deployments on the go. Developers editing remote files and running quick commands. Homelab enthusiasts managing personal infrastructure.
```

#### Keywords (100 chars)
```
ssh,terminal,sftp,client,ios,server,shell,remote,key-based,authentication
```

#### What's New (Release Notes)
```
Launch day! mSSH brings secure SSH and SFTP access to your iPhone and iPad. Built from the ground up for iOS 18+.

What's Included:
- SSH Terminal with full xterm-256color support
- Password and key-based auth (Ed25519, ECDSA, RSA)
- SFTP File Browser for remote file management
- Keychain security with Face ID/Touch ID support
- Connection Profiles with iCloud sync
- Host Key Verification (TOFU) with SHA-256 fingerprints
```

#### Support URL
```
https://nirasnet.github.io/mssh-privacy/
```

#### Privacy Policy URL
```
https://nirasnet.github.io/mssh-privacy/
```

#### Category
- Primary: **Utilities**
- Secondary: **Productivity**

#### Age Rating: **4+**

### 4. Upload Screenshots
Upload from your `mssh/screenshots/` folder (all 1290x2796, iPhone 6.7"):

| Order | File | Feature |
|-------|------|---------|
| 1 | `screenshot_1_hero.png` | Terminal hero shot |
| 2 | `screenshot_2_connections.png` | Server list |
| 3 | `screenshot_3_security.png` | Security features |
| 4 | `screenshot_4_sftp.png` | File browser |
| 5 | `screenshot_5_sync.png` | iCloud sync |

### 5. Add Review Notes
```
mSSH is an SSH terminal client. To test:
1. Launch the app
2. Tap + to add a connection
3. Enter any SSH server (host, port 22, username, password)
4. Tap Connect

The app requires a real SSH server to connect to.
No demo server is provided.
No login/account required to use the app.
```

### 6. Submit for Review
Click **Submit for Review** and you're done!

---

## Privacy Policy URL
Your privacy policy is live at:
**https://nirasnet.github.io/mssh-privacy/**

(It may take 1-2 minutes after deployment for the first visit)

---

## Launch Tips
- Week 1: Submit as free with all features unlocked (no IAP yet)
- Week 2-3: Implement StoreKit 2 IAP code, add paywall, submit v1.1
- Post on Reddit r/selfhosted, r/homelab, r/sysadmin, Hacker News
- Respond to every App Store review
