import UIKit
import SwiftTerm

/// Custom keyboard accessory bar with special keys needed for terminal use on iOS
final class TerminalAccessoryBar: UIView {
    weak var terminal: TerminalView?

    private let keys: [(String, [UInt8])] = [
        ("Esc", [0x1B]),
        ("Tab", [0x09]),
        ("Ctrl", []),  // modifier
        ("|", [0x7C]),
        ("~", [0x7E]),
        ("/", [0x2F]),
        ("-", [0x2D]),
        ("\u{2190}", [0x1B, 0x5B, 0x44]),  // Left arrow
        ("\u{2191}", [0x1B, 0x5B, 0x41]),  // Up arrow
        ("\u{2192}", [0x1B, 0x5B, 0x43]),  // Right arrow
        ("\u{2193}", [0x1B, 0x5B, 0x42]),  // Down arrow
    ]

    private var ctrlActive = false
    private var ctrlButton: UIButton?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        autoresizingMask = .flexibleWidth
        setupAppearance()
        setupKeys()
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupAppearance() {
        backgroundColor = UIColor.secondarySystemBackground
        // Add a subtle top border
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func setupKeys() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // Dismiss keyboard button pinned to right edge
        let dismissButton = UIButton(type: .system)
        let dismissConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        dismissButton.setImage(UIImage(systemName: "chevron.down", withConfiguration: dismissConfig), for: .normal)
        dismissButton.tintColor = .label
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        dismissButton.backgroundColor = UIColor.tertiarySystemBackground
        dismissButton.layer.cornerRadius = 6
        dismissButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        addSubview(dismissButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -4),

            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        stack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        for (index, key) in keys.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(key.0, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
            button.tintColor = .label
            button.tag = index
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            button.backgroundColor = UIColor.tertiarySystemBackground
            button.layer.cornerRadius = 6
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.layer.shadowRadius = 0.5
            button.layer.shadowOpacity = 0.15
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

            if key.0 == "Ctrl" {
                ctrlButton = button
            }

            stack.addArrangedSubview(button)
        }
    }

    @objc private func dismissKeyboard() {
        feedbackGenerator.impactOccurred()
        terminal?.resignFirstResponder()
    }

    @objc private func keyTapped(_ sender: UIButton) {
        feedbackGenerator.impactOccurred()

        let index = sender.tag
        let key = keys[index]

        if key.0 == "Ctrl" {
            ctrlActive.toggle()
            UIView.animate(withDuration: 0.15) {
                self.ctrlButton?.backgroundColor = self.ctrlActive
                    ? UIColor.systemBlue.withAlphaComponent(0.3)
                    : UIColor.tertiarySystemBackground
                self.ctrlButton?.tintColor = self.ctrlActive ? .systemBlue : .label
            }
            return
        }

        if ctrlActive && key.1.count == 1 {
            // Send Ctrl+key: for printable ASCII, Ctrl version is (char & 0x1F)
            let ctrlByte = key.1[0] & 0x1F
            terminal?.terminalDelegate?.send(source: terminal!, data: ArraySlice([ctrlByte]))
            ctrlActive = false
            UIView.animate(withDuration: 0.15) {
                self.ctrlButton?.backgroundColor = UIColor.tertiarySystemBackground
                self.ctrlButton?.tintColor = .label
            }
        } else {
            // Send the raw bytes through the delegate
            let data = ArraySlice(key.1)
            if let terminalView = terminal {
                terminalView.terminalDelegate?.send(source: terminalView, data: data)
            }
        }

        // Brief press animation
        UIView.animate(withDuration: 0.08, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                sender.transform = .identity
            }
        }
    }
}
