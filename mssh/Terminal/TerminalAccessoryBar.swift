#if os(iOS)
import UIKit
import SwiftTerm

/// Custom keyboard accessory bar with terminal-essential keys for iOS.
/// Designed with minimal dark aesthetic matching the app theme.
final class TerminalAccessoryBar: UIView {
    weak var terminal: TerminalView?

    // Key definitions: (label, bytes to send, isSpecial)
    private struct KeyDef {
        let label: String
        let bytes: [UInt8]
        let isModifier: Bool
        let icon: String?

        init(_ label: String, _ bytes: [UInt8], isModifier: Bool = false, icon: String? = nil) {
            self.label = label
            self.bytes = bytes
            self.isModifier = isModifier
            self.icon = icon
        }
    }

    private let keyDefs: [KeyDef] = [
        KeyDef("Esc", [0x1B]),
        KeyDef("Tab", [0x09]),
        KeyDef("Ctrl", [], isModifier: true),
        KeyDef("|", [0x7C]),
        KeyDef("~", [0x7E]),
        KeyDef("/", [0x2F]),
        KeyDef("-", [0x2D]),
        KeyDef("_", [0x5F]),
        KeyDef(".", [0x2E]),
        KeyDef(":", [0x3A]),
        KeyDef("$", [0x24]),
        KeyDef("\u{2190}", [0x1B, 0x5B, 0x44]),  // Left
        KeyDef("\u{2191}", [0x1B, 0x5B, 0x41]),  // Up
        KeyDef("\u{2193}", [0x1B, 0x5B, 0x42]),  // Down
        KeyDef("\u{2192}", [0x1B, 0x5B, 0x43]),  // Right
    ]

    private var ctrlActive = false
    private var ctrlButton: UIButton?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // Colors matching AppColors design system
    private let bgColor = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
    private let keyColor = UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1)
    private let keyTextColor = UIColor(red: 0.85, green: 0.85, blue: 0.88, alpha: 1)
    private let accentColor = UIColor(red: 0.30, green: 0.85, blue: 0.85, alpha: 1)
    private let borderColor = UIColor.white.withAlphaComponent(0.06)

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 46))
        autoresizingMask = .flexibleWidth
        setupAppearance()
        setupKeys()
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupAppearance() {
        backgroundColor = bgColor

        let topBorder = UIView()
        topBorder.backgroundColor = borderColor
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)
        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func setupKeys() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Dismiss keyboard button
        let dismissButton = makeKeyButton(
            title: nil,
            icon: "chevron.down",
            width: 40,
            action: #selector(dismissKeyboard)
        )
        addSubview(dismissButton)

        // Snippets button — posts a notification that the active terminal view
        // listens to in order to present the SnippetPickerView sheet.
        let snippetButton = makeKeyButton(
            title: nil,
            icon: "text.badge.plus",
            width: 40,
            action: #selector(openSnippetPicker)
        )
        snippetButton.tintColor = accentColor
        addSubview(snippetButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: snippetButton.leadingAnchor, constant: -4),

            snippetButton.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            snippetButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            snippetButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -4),
            snippetButton.widthAnchor.constraint(equalToConstant: 40),

            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 5
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutMargins = UIEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
        stack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        for (index, keyDef) in keyDefs.enumerated() {
            let isArrow = keyDef.label.unicodeScalars.first.map { $0.value >= 0x2190 && $0.value <= 0x2193 } ?? false
            let minWidth: CGFloat = isArrow ? 36 : (keyDef.label.count > 2 ? 44 : 34)

            let button = UIButton(type: .system)
            button.setTitle(keyDef.label, for: .normal)

            if keyDef.isModifier {
                button.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
            } else if isArrow {
                button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
            } else {
                button.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
            }

            button.tintColor = keyTextColor
            button.tag = index
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            button.backgroundColor = keyColor
            button.layer.cornerRadius = 5
            button.layer.borderWidth = 0.5
            button.layer.borderColor = borderColor.cgColor

            let widthConstraint = button.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
            widthConstraint.isActive = true
            var btnConfig = UIButton.Configuration.plain()
            btnConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            button.configuration = btnConfig

            if keyDef.isModifier {
                ctrlButton = button
            }

            stack.addArrangedSubview(button)
        }
    }

    private func makeKeyButton(title: String?, icon: String?, width: CGFloat, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        if let title = title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        }
        if let icon = icon {
            let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        }
        button.tintColor = keyTextColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = keyColor
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 0.5
        button.layer.borderColor = borderColor.cgColor
        return button
    }

    @objc private func dismissKeyboard() {
        feedbackGenerator.impactOccurred()
        terminal?.resignFirstResponder()
    }

    @objc private func openSnippetPicker() {
        feedbackGenerator.impactOccurred()
        NotificationCenter.default.post(name: .openSnippetPicker, object: nil)
    }

    @objc private func keyTapped(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()

        let index = sender.tag
        let keyDef = keyDefs[index]

        if keyDef.isModifier {
            ctrlActive.toggle()
            UIView.animate(withDuration: 0.12) {
                self.ctrlButton?.backgroundColor = self.ctrlActive
                    ? self.accentColor.withAlphaComponent(0.25)
                    : self.keyColor
                self.ctrlButton?.tintColor = self.ctrlActive ? self.accentColor : self.keyTextColor
                self.ctrlButton?.layer.borderColor = self.ctrlActive
                    ? self.accentColor.withAlphaComponent(0.5).cgColor
                    : self.borderColor.cgColor
            }
            return
        }

        guard let terminal else { return }

        if ctrlActive && keyDef.bytes.count == 1 {
            let ctrlByte = keyDef.bytes[0] & 0x1F
            terminal.terminalDelegate?.send(source: terminal, data: ArraySlice([ctrlByte]))
            deactivateCtrl()
        } else {
            terminal.terminalDelegate?.send(source: terminal, data: ArraySlice(keyDef.bytes))
        }

        // Subtle press animation
        UIView.animate(withDuration: 0.06, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
            sender.alpha = 0.7
        }) { _ in
            UIView.animate(withDuration: 0.06) {
                sender.transform = .identity
                sender.alpha = 1.0
            }
        }
    }

    private func deactivateCtrl() {
        ctrlActive = false
        UIView.animate(withDuration: 0.12) {
            self.ctrlButton?.backgroundColor = self.keyColor
            self.ctrlButton?.tintColor = self.keyTextColor
            self.ctrlButton?.layer.borderColor = self.borderColor.cgColor
        }
    }
}

#endif
