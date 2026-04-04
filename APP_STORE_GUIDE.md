# mSSH — App Store Submission Guide

Everything you need to submit mSSH to the App Store. All assets are ready in this project folder.

---

## Step-by-Step Submission

### 1. Host Your Privacy Policy

Upload `privacy-policy.html` to a public URL. Options:

**GitHub Pages (free, easiest):**
1. Create a repo: `github.com/YOUR_USERNAME/mssh-privacy`
2. Upload `privacy-policy.html` as `index.html`
3. Enable Pages in Settings → Pages → Deploy from `main`
4. Your URL: `https://YOUR_USERNAME.github.io/mssh-privacy/`

### 2. Create App in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `mSSH`
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.m4ck.mssh`
   - **SKU**: `mssh-ios-001`

### 3. Enter App Information

Copy from `AppStoreMetadata.md`:

| Field | Value |
|-------|-------|
| **Name** | mSSH |
| **Subtitle** | SSH Terminal for iOS |
| **Category** | Utilities (Primary), Productivity (Secondary) |
| **Age Rating** | 4+ |
| **Privacy Policy URL** | Your hosted URL from step 1 |
| **Support URL** | Same URL or your email |

### 4. Upload Screenshots

Upload from `screenshots/` folder (all 1290x2796, iPhone 6.7"):

| Order | File | Feature |
|-------|------|---------|
| 1 | `screenshot_1_hero.png` | Terminal hero shot |
| 2 | `screenshot_2_connections.png` | Server list |
| 3 | `screenshot_3_security.png` | Security features |
| 4 | `screenshot_4_sftp.png` | File browser |
| 5 | `screenshot_5_sync.png` | iCloud sync |

> **Note**: You need screenshots for each device size. Use these for 6.7" iPhone. For 6.5" and iPad, App Store Connect can auto-generate from 6.7".

### 5. Upload App Icon

The icon `AppIcon.png` (1024x1024) goes in:
- **App Store Connect**: Upload in the App Information section
- **Xcode**: Add to your asset catalog (`Assets.xcassets/AppIcon`)

### 6. Set Up In-App Purchases

In App Store Connect → **In-App Purchases**:

| Product ID | Type | Price | Name |
|-----------|------|-------|------|
| `com.m4ck.mssh.pro.monthly` | Auto-Renewable | $4.99/mo | mSSH Pro (Monthly) |
| `com.m4ck.mssh.pro.yearly` | Auto-Renewable | $49.99/yr | mSSH Pro (Yearly) |
| `com.m4ck.mssh.pro.lifetime` | Non-Consumable | $19.99 | mSSH Pro (Lifetime) |

**Free features**: 2 connection profiles, SSH terminal, SFTP, host key management
**Pro features**: Unlimited profiles, Face ID lock, iCloud sync, advanced key management

> **Important**: IAP code needs to be implemented in the app before these will work. For v1.0 launch, you can submit without IAP and add it in v1.1, making all features free initially to build reviews.

### 7. Upload Build via Xcode

1. In Xcode: **Product** → **Archive**
2. In Organizer: Click **Distribute App** → **App Store Connect**
3. Wait for processing (~15 minutes)
4. In App Store Connect: Select the build under your app version

### 8. Submit for Review

1. Fill in the **What's New** text (from `AppStoreMetadata.md`)
2. Enter your **promotional text**
3. Add **description** (copy from metadata file)
4. Add **keywords**: `ssh,terminal,sftp,client,ios,server,shell,remote,key-based,authentication`
5. Click **Submit for Review**

### 9. Review Notes (for Apple Reviewer)

Add this in the review notes field:

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

---

## File Inventory

```
mssh/
├── AppIcon.png                          — 1024x1024 app icon
├── AppStoreMetadata.md                  — All copy (description, keywords, etc.)
├── privacy-policy.html                  — Privacy policy (host this publicly)
├── APP_STORE_GUIDE.md                   — This guide
└── screenshots/
    ├── screenshot_1_hero.png            — Terminal hero (1290x2796)
    ├── screenshot_2_connections.png     — Server list (1290x2796)
    ├── screenshot_3_security.png        — Security features (1290x2796)
    ├── screenshot_4_sftp.png            — File browser (1290x2796)
    └── screenshot_5_sync.png           — iCloud sync (1290x2796)
```

---

## Launch Strategy Tips

**Week 1**: Submit as free with all features unlocked (no IAP yet). Get initial downloads and reviews.

**Week 2-3**: Implement StoreKit 2 IAP code, add paywall. Submit update as v1.1.

**Ongoing**: Respond to every App Store review. Ask happy users to rate. Post on Reddit r/selfhosted, r/homelab, r/sysadmin, Hacker News.

---

Good luck with the launch! 🚀
