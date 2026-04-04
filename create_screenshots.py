#!/usr/bin/env python3
"""
Create professional App Store promotional screenshots for mSSH iOS app.
1290x2796 pixels (iPhone 15 Pro Max / 6.7" display size)
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Colors
BG_DARK = (11, 20, 38)          # #0B1426
BG_DARKER = (15, 29, 53)        # #0F1D35
ACCENT_TEAL = (34, 197, 194)    # #22C5C2
ACCENT_CYAN = (0, 229, 204)     # #00E5CC
TEXT_WHITE = (255, 255, 255)
TEXT_GRAY = (148, 163, 184)     # #94A3B8
TERMINAL_BG = (30, 41, 59)      # #1E293B
ACCENT_GREEN = (34, 197, 97)    # #22C560
ACCENT_RED = (239, 68, 68)      # #EF4444

# Font paths
FONT_DIR = "/sessions/sleepy-admiring-einstein/mnt/.claude/skills/canvas-design/canvas-fonts/"
FONT_HEADLINE = FONT_DIR + "InstrumentSans-Bold.ttf"
FONT_TERMINAL = FONT_DIR + "GeistMono-Regular.ttf"
FONT_BODY = FONT_DIR + "WorkSans-Regular.ttf"

# Dimensions
WIDTH = 1290
HEIGHT = 2796

def create_gradient_bg(width, height, color1, color2):
    """Create vertical gradient background"""
    img = Image.new('RGB', (width, height))
    pixels = img.load()

    for y in range(height):
        r = int(color1[0] + (color2[0] - color1[0]) * y / height)
        g = int(color1[1] + (color2[1] - color1[1]) * y / height)
        b = int(color1[2] + (color2[2] - color1[2]) * y / height)
        for x in range(width):
            pixels[x, y] = (r, g, b)

    return img

def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle"""
    x0, y0, x1, y1 = bbox

    # Draw four corners as circles
    draw.arc([x0, y0, x0 + radius*2, y0 + radius*2], 180, 270, fill=outline, width=width)
    draw.arc([x1 - radius*2, y0, x1, y0 + radius*2], 270, 0, fill=outline, width=width)
    draw.arc([x1 - radius*2, y1 - radius*2, x1, y1], 0, 90, fill=outline, width=width)
    draw.arc([x0, y1 - radius*2, x0 + radius*2, y1], 90, 180, fill=outline, width=width)

    # Draw connecting lines
    draw.line([(x0 + radius, y0), (x1 - radius, y0)], fill=outline, width=width)
    draw.line([(x1, y0 + radius), (x1, y1 - radius)], fill=outline, width=width)
    draw.line([(x0 + radius, y1), (x1 - radius, y1)], fill=outline, width=width)
    draw.line([(x0, y0 + radius), (x0, y1 - radius)], fill=outline, width=width)

    # Fill interior
    if fill:
        draw.rectangle([x0 + radius, y0, x1 - radius, y0 + radius*2], fill=fill)
        draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
        draw.rectangle([x0 + radius, y1 - radius*2, x1 - radius, y1], fill=fill)

def add_branding(img):
    """Add mSSH branding to bottom right"""
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_BODY, 36)
    text = "mSSH"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = WIDTH - text_width - 40
    y = HEIGHT - text_height - 40
    draw.text((x, y), text, fill=TEXT_GRAY, font=font)

def screenshot_1_hero():
    """Hero screenshot - Terminal mockup with live session"""
    img = create_gradient_bg(WIDTH, HEIGHT, BG_DARK, BG_DARKER)
    draw = ImageDraw.Draw(img)

    # Headline
    font_headline = ImageFont.truetype(FONT_HEADLINE, 90)
    headline = "Your Server.\nYour Pocket."
    y_pos = 150
    for line in headline.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_headline)
        line_height = bbox[3] - bbox[1]
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_pos), line, fill=TEXT_WHITE, font=font_headline)
        y_pos += line_height + 20

    # Subheading
    font_sub = ImageFont.truetype(FONT_BODY, 48)
    subhead = "Secure SSH terminal for iOS"
    bbox = draw.textbbox((0, 0), subhead, font=font_sub)
    x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
    draw.text((x_pos, y_pos + 40), subhead, fill=TEXT_GRAY, font=font_sub)

    # Terminal mockup window
    term_y = 520
    term_height = 1800
    term_margin = 45

    # Terminal window background
    draw.rectangle([term_margin, term_y, WIDTH - term_margin, term_y + term_height],
                   fill=TERMINAL_BG)

    # Terminal title bar
    draw.rectangle([term_margin, term_y, WIDTH - term_margin, term_y + 80],
                   fill=(20, 30, 45))

    # Traffic light buttons
    colors_traffic = [ACCENT_RED, (248, 180, 60), ACCENT_GREEN]
    for i, color in enumerate(colors_traffic):
        cx = term_margin + 65 + i * 30
        cy = term_y + 40
        draw.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=color)

    # Terminal title text
    font_term_title = ImageFont.truetype(FONT_TERMINAL, 32)
    draw.text((term_margin + 120, term_y + 20), "user@prod-server:~$", fill=TEXT_GRAY, font=font_term_title)

    # Terminal content - simulate ls --color output
    font_term = ImageFont.truetype(FONT_TERMINAL, 40)
    terminal_content = [
        ("$ ls -lah", TEXT_GRAY),
        ("total 2.4G", TEXT_GRAY),
        ("drwxr-xr-x  8 user  staff   256B  Mar 28 14:32 .", ACCENT_CYAN),
        ("drwxr-xr-x  5 root  wheel   160B  Jan  5 08:00 ..", ACCENT_CYAN),
        ("-rw-r--r--  1 user  staff   1.2K  Mar 28 14:32 README.md", TEXT_WHITE),
        ("drwxr-xr-x  3 user  staff   96B  Mar 28 14:32 src/", ACCENT_TEAL),
        ("drwxr-xr-x  2 user  staff   64B  Mar 28 14:32 bin/", ACCENT_TEAL),
        ("-rw-r--r--  1 user  staff   4.3K  Mar 25 09:15 config.yaml", TEXT_WHITE),
        ("$ htop", TEXT_GRAY),
        ("", TEXT_GRAY),
        ("CPU:  [████████░░░░░░░░░░░░░░] 38%", ACCENT_GREEN),
        ("MEM:  [██████░░░░░░░░░░░░░░░░] 24%", ACCENT_GREEN),
        ("SWP:  [░░░░░░░░░░░░░░░░░░░░░░] 0%", ACCENT_GREEN),
    ]

    y_content = term_y + 140
    for text, color in terminal_content:
        draw.text((term_margin + 40, y_content), text, fill=color, font=font_term)
        y_content += 80

    # Add branding
    add_branding(img)

    return img

def screenshot_2_connections():
    """Connections screenshot - Server list mockup"""
    img = create_gradient_bg(WIDTH, HEIGHT, BG_DARK, BG_DARKER)
    draw = ImageDraw.Draw(img)

    # Headline
    font_headline = ImageFont.truetype(FONT_HEADLINE, 80)
    headline = "All Servers.\nOne Tap."
    y_pos = 150
    for line in headline.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_headline)
        line_height = bbox[3] - bbox[1]
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_pos), line, fill=TEXT_WHITE, font=font_headline)
        y_pos += line_height + 20

    # Connection cards
    servers = [
        ("Production AWS", "54.203.45.12", ACCENT_GREEN),
        ("Dev Server", "192.168.1.50", ACCENT_GREEN),
        ("Database Replica", "10.0.2.100", ACCENT_GREEN),
        ("Staging EU", "52.89.123.45", ACCENT_TEAL),
        ("Backup Server", "192.168.1.99", TEXT_GRAY),
    ]

    card_margin = 40
    card_width = WIDTH - (card_margin * 2)
    card_height = 160
    card_y = 500

    for i, (name, ip, status_color) in enumerate(servers):
        y = card_y + i * (card_height + 30)

        # Card background
        draw.rectangle([card_margin, y, card_margin + card_width, y + card_height],
                      fill=(20, 30, 45), outline=(50, 70, 100), width=2)

        # Status indicator (dot)
        dot_x = card_margin + 35
        dot_y = y + card_height // 2
        draw.ellipse([dot_x - 12, dot_y - 12, dot_x + 12, dot_y + 12], fill=status_color)

        # Server name
        font_name = ImageFont.truetype(FONT_BODY, 48)
        draw.text((card_margin + 80, y + 30), name, fill=TEXT_WHITE, font=font_name)

        # IP address
        font_ip = ImageFont.truetype(FONT_TERMINAL, 36)
        draw.text((card_margin + 80, y + 90), ip, fill=TEXT_GRAY, font=font_ip)

    # Add branding
    add_branding(img)

    return img

def screenshot_3_security():
    """Security screenshot - Security features"""
    img = create_gradient_bg(WIDTH, HEIGHT, BG_DARK, BG_DARKER)
    draw = ImageDraw.Draw(img)

    # Headline
    font_headline = ImageFont.truetype(FONT_HEADLINE, 80)
    headline = "Military-Grade\nSecurity"
    y_pos = 150
    for line in headline.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_headline)
        line_height = bbox[3] - bbox[1]
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_pos), line, fill=TEXT_WHITE, font=font_headline)
        y_pos += line_height + 20

    # Security feature cards
    features = [
        ("🔒", "Keychain\nEncrypted", "All credentials protected by iOS Keychain"),
        ("🔐", "Face ID\nLock", "Biometric authentication for app access"),
        ("🔑", "SSH Key\nAuth", "Support for RSA, ECDSA, and Ed25519 keys"),
    ]

    card_width = (WIDTH - 80) // 3
    card_height = 500
    card_y = 500

    for i, (icon, title, desc) in enumerate(features):
        x = 40 + i * (card_width + 20)
        y = card_y

        # Card background
        draw.rectangle([x, y, x + card_width, y + card_height],
                      fill=(20, 30, 45), outline=ACCENT_TEAL, width=3)

        # Icon (large)
        font_icon = ImageFont.truetype(FONT_BODY, 100)
        bbox = draw.textbbox((0, 0), icon, font=font_icon)
        icon_x = x + (card_width - (bbox[2] - bbox[0])) // 2
        draw.text((icon_x, y + 40), icon, fill=ACCENT_TEAL, font=font_icon)

        # Title
        font_title = ImageFont.truetype(FONT_HEADLINE, 42)
        title_lines = title.split('\n')
        title_y = y + 180
        for line in title_lines:
            bbox = draw.textbbox((0, 0), line, font=font_title)
            line_x = x + (card_width - (bbox[2] - bbox[0])) // 2
            draw.text((line_x, title_y), line, fill=TEXT_WHITE, font=font_title)
            title_y += 70

        # Description
        font_desc = ImageFont.truetype(FONT_BODY, 28)
        desc_y = y + 350
        draw.text((x + 15, desc_y), desc, fill=TEXT_GRAY, font=font_desc, align="center")

    # Add branding
    add_branding(img)

    return img

def screenshot_4_sftp():
    """SFTP screenshot - File browser mockup"""
    img = create_gradient_bg(WIDTH, HEIGHT, BG_DARK, BG_DARKER)
    draw = ImageDraw.Draw(img)

    # Headline
    font_headline = ImageFont.truetype(FONT_HEADLINE, 80)
    headline = "Browse Files.\nAnywhere."
    y_pos = 150
    for line in headline.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_headline)
        line_height = bbox[3] - bbox[1]
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_pos), line, fill=TEXT_WHITE, font=font_headline)
        y_pos += line_height + 20

    # File browser mockup
    browser_y = 500
    browser_margin = 40

    # Navigation bar
    draw.rectangle([browser_margin, browser_y, WIDTH - browser_margin, browser_y + 80],
                  fill=(20, 30, 45), outline=(50, 70, 100), width=2)
    font_nav = ImageFont.truetype(FONT_BODY, 40)
    draw.text((browser_margin + 30, browser_y + 20), "/home/user/projects", fill=ACCENT_TEAL, font=font_nav)

    # File list
    files = [
        ("📁", "var", "4.2 GB", ACCENT_TEAL),
        ("📁", "etc", "256 MB", ACCENT_TEAL),
        ("📄", "README.md", "2.3 KB", TEXT_WHITE),
        ("📁", "nginx", "512 MB", ACCENT_TEAL),
        ("📄", "config.json", "4.1 KB", TEXT_WHITE),
        ("📄", "package.json", "1.8 KB", TEXT_WHITE),
        ("📁", ".git", "156 MB", ACCENT_TEAL),
        ("📄", "Dockerfile", "892 B", TEXT_WHITE),
    ]

    file_y = browser_y + 120
    font_filename = ImageFont.truetype(FONT_BODY, 44)
    font_size = ImageFont.truetype(FONT_TERMINAL, 36)

    for icon, name, size, color in files:
        # Icon
        draw.text((browser_margin + 30, file_y + 10), icon, fill=color, font=font_filename)

        # Filename
        draw.text((browser_margin + 110, file_y), name, fill=TEXT_WHITE, font=font_filename)

        # File size (right aligned)
        bbox = draw.textbbox((0, 0), size, font=font_size)
        size_x = WIDTH - browser_margin - 30 - (bbox[2] - bbox[0])
        draw.text((size_x, file_y + 15), size, fill=TEXT_GRAY, font=font_size)

        # Separator line
        draw.line([(browser_margin + 20, file_y + 75), (WIDTH - browser_margin - 20, file_y + 75)],
                 fill=(50, 70, 100), width=1)

        file_y += 100

    # Add branding
    add_branding(img)

    return img

def screenshot_5_sync():
    """Sync screenshot - iCloud sync across devices"""
    img = create_gradient_bg(WIDTH, HEIGHT, BG_DARK, BG_DARKER)
    draw = ImageDraw.Draw(img)

    # Headline
    font_headline = ImageFont.truetype(FONT_HEADLINE, 80)
    headline = "Seamless Across\nDevices"
    y_pos = 150
    for line in headline.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_headline)
        line_height = bbox[3] - bbox[1]
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_pos), line, fill=TEXT_WHITE, font=font_headline)
        y_pos += line_height + 20

    # Device mockups and sync icon
    device_y = 600

    # Left device (iPhone) mockup
    iphone_x = 100
    iphone_width = 350
    iphone_height = 700

    # Phone bezel
    draw.rectangle([iphone_x, device_y, iphone_x + iphone_width, device_y + iphone_height],
                  outline=TEXT_GRAY, width=8)
    # Notch
    draw.rectangle([iphone_x + 120, device_y, iphone_x + 230, device_y + 60],
                  fill=BG_DARKER, outline=TEXT_GRAY, width=2)

    # Phone screen
    draw.rectangle([iphone_x + 15, device_y + 70, iphone_x + iphone_width - 15, device_y + iphone_height - 20],
                  fill=(20, 30, 45))

    # Phone content
    font_small = ImageFont.truetype(FONT_BODY, 32)
    draw.text((iphone_x + 40, device_y + 120), "Production", fill=ACCENT_TEAL, font=font_small)
    draw.text((iphone_x + 40, device_y + 180), "Dev Server", fill=TEXT_WHITE, font=font_small)
    draw.text((iphone_x + 40, device_y + 240), "Database", fill=TEXT_WHITE, font=font_small)

    # Right device (iPad) mockup
    ipad_x = WIDTH - 100 - 400
    ipad_width = 400
    ipad_height = 550

    # iPad bezel
    draw.rectangle([ipad_x, device_y + 75, ipad_x + ipad_width, device_y + ipad_height + 75],
                  outline=TEXT_GRAY, width=8)

    # iPad screen
    draw.rectangle([ipad_x + 15, device_y + 90, ipad_x + ipad_width - 15, device_y + ipad_height + 60],
                  fill=(20, 30, 45))

    # iPad content (wider layout)
    draw.text((ipad_x + 40, device_y + 140), "Production", fill=ACCENT_TEAL, font=font_small)
    draw.text((ipad_x + 40, device_y + 200), "Dev Server", fill=TEXT_WHITE, font=font_small)
    draw.text((ipad_x + 40, device_y + 260), "Database", fill=TEXT_WHITE, font=font_small)

    # Cloud/Sync icon in the middle
    cloud_x = WIDTH // 2
    cloud_y = device_y + 300

    # Draw sync arrows
    font_sync = ImageFont.truetype(FONT_BODY, 120)
    draw.text((cloud_x - 60, cloud_y - 60), "☁", fill=ACCENT_CYAN, font=font_sync)

    # Arrows pointing both directions
    arrow_size = 6
    # Left arrow
    arrow_x = iphone_x + iphone_width + 20
    arrow_y = cloud_y
    draw.polygon([(arrow_x, arrow_y), (arrow_x + 40, arrow_y - 30), (arrow_x + 40, arrow_y + 30)],
                fill=ACCENT_CYAN, outline=ACCENT_CYAN)

    # Right arrow
    arrow_x = ipad_x - 60
    arrow_y = cloud_y
    draw.polygon([(arrow_x, arrow_y), (arrow_x - 40, arrow_y - 30), (arrow_x - 40, arrow_y + 30)],
                fill=ACCENT_CYAN, outline=ACCENT_CYAN)

    # Subtext
    font_sub = ImageFont.truetype(FONT_BODY, 44)
    subtext = "iCloud sync keeps your\nconnections everywhere"
    y_text = device_y + iphone_height + 100
    for line in subtext.split('\n'):
        bbox = draw.textbbox((0, 0), line, font=font_sub)
        x_pos = (WIDTH - (bbox[2] - bbox[0])) // 2
        draw.text((x_pos, y_text), line, fill=TEXT_GRAY, font=font_sub)
        y_text += 80

    # Add branding
    add_branding(img)

    return img

def main():
    """Generate all screenshots"""
    output_dir = "/sessions/sleepy-admiring-einstein/mnt/mssh/screenshots/"
    os.makedirs(output_dir, exist_ok=True)

    screenshots = [
        ("screenshot_1_hero.png", screenshot_1_hero),
        ("screenshot_2_connections.png", screenshot_2_connections),
        ("screenshot_3_security.png", screenshot_3_security),
        ("screenshot_4_sftp.png", screenshot_4_sftp),
        ("screenshot_5_sync.png", screenshot_5_sync),
    ]

    for filename, func in screenshots:
        print(f"Generating {filename}...")
        img = func()
        img.save(output_dir + filename, quality=95)
        print(f"  ✓ Saved to {output_dir + filename}")

    print("\nAll screenshots generated successfully!")

if __name__ == "__main__":
    main()
