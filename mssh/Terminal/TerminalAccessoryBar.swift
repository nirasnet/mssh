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

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        autoresizingMask = .flexibleWidth
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        setupKeys()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupKeys() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
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
            button.tag = index
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            button.backgroundColor = UIColor.secondarySystemBackground
            button.layer.cornerRadius = 6
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)

            if key.0 == "Ctrl" {
                ctrlButton = button
            }

            stack.addArrangedSubview(button)
        }
    }

    @objc private func keyTapped(_ sender: UIButton) {
        let index = sender.tag
        let key = keys[index]

        if key.0 == "Ctrl" {
            ctrlActive.toggle()
            ctrlButton?.backgroundColor = ctrlActive
                ? UIColor.systemBlue.withAlphaComponent(0.3)
                : UIColor.secondarySystemBackground
            return
        }

        if ctrlActive && key.1.count == 1 {
            // Send Ctrl+key: for printable ASCII, Ctrl version is (char & 0x1F)
            let ctrlByte = key.1[0] & 0x1F
            terminal?.terminalDelegate?.send(source: terminal!, data: ArraySlice([ctrlByte]))
            ctrlActive = false
            ctrlButton?.backgroundColor = UIColor.secondarySystemBackground
        } else {
            // Send the raw bytes through the delegate
            let data = ArraySlice(key.1)
            if let terminalView = terminal {
                terminalView.terminalDelegate?.send(source: terminalView, data: data)
            }
        }
    }
}
