import Cocoa

/// A single-instance settings window that lets the user enter their
/// GitHub Personal Access Token, repository owner, and repository name.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private var tokenField: NSSecureTextField!
    private var ownerField: NSTextField!
    private var repoField: NSTextField!

    // MARK: - Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GitHub Actions Menu Bar – Settings"
        window.center()
        self.init(window: window)
        buildUI()
    }

    // MARK: - UI layout

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let leftMargin:  CGFloat = 20
        let labelWidth:  CGFloat = 150
        let fieldLeft:   CGFloat = leftMargin + labelWidth + 8
        let fieldWidth:  CGFloat = 240
        let rowHeight:   CGFloat = 26
        let rowSpacing:  CGFloat = 14
        var y:           CGFloat = 210

        // ── GitHub Token ──────────────────────────────────────────────────
        addLabel("GitHub Token:", in: contentView,
                 frame: NSRect(x: leftMargin, y: y, width: labelWidth, height: rowHeight))

        tokenField = NSSecureTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowHeight))
        tokenField.placeholderString = "ghp_xxxxxxxxxxxx"
        contentView.addSubview(tokenField)
        y -= rowHeight + rowSpacing

        // ── Repository Owner ──────────────────────────────────────────────
        addLabel("Repository Owner:", in: contentView,
                 frame: NSRect(x: leftMargin, y: y, width: labelWidth, height: rowHeight))

        ownerField = NSTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowHeight))
        ownerField.placeholderString = "e.g. octocat"
        contentView.addSubview(ownerField)
        y -= rowHeight + rowSpacing

        // ── Repository Name ───────────────────────────────────────────────
        addLabel("Repository Name:", in: contentView,
                 frame: NSRect(x: leftMargin, y: y, width: labelWidth, height: rowHeight))

        repoField = NSTextField(frame: NSRect(x: fieldLeft, y: y, width: fieldWidth, height: rowHeight))
        repoField.placeholderString = "e.g. my-project"
        contentView.addSubview(repoField)
        y -= rowHeight + rowSpacing

        // ── Help text ─────────────────────────────────────────────────────
        let helpText = NSTextField(labelWithString:
            "Create a token at github.com/settings/tokens (classic) with the " +
            "'repo' scope, or a fine-grained token with Actions read access.")
        helpText.frame = NSRect(x: leftMargin, y: y - 10, width: fieldLeft + fieldWidth - leftMargin, height: 40)
        helpText.font = .systemFont(ofSize: 11)
        helpText.textColor = .secondaryLabelColor
        helpText.maximumNumberOfLines = 2
        contentView.addSubview(helpText)

        // ── Buttons ───────────────────────────────────────────────────────
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.frame = NSRect(x: fieldLeft + fieldWidth - 80, y: 16, width: 80, height: 32)
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.frame = NSRect(x: fieldLeft + fieldWidth - 170, y: 16, width: 80, height: 32)
        cancelButton.keyEquivalent = "\u{1B}"  // Escape
        contentView.addSubview(cancelButton)
    }

    @discardableResult
    private func addLabel(_ text: String, in view: NSView, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.alignment = .right
        view.addSubview(label)
        return label
    }

    // MARK: - Show / hide

    /// Loads current preferences into fields and brings the window to the front.
    func showWindow() {
        let prefs = UserPreferences.shared
        tokenField.stringValue = prefs.githubToken
        ownerField.stringValue = prefs.repoOwner
        repoField.stringValue  = prefs.repoName

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Actions

    @objc private func save() {
        let prefs       = UserPreferences.shared
        prefs.githubToken = tokenField.stringValue.trimmingCharacters(in: .whitespaces)
        prefs.repoOwner   = ownerField.stringValue.trimmingCharacters(in: .whitespaces)
        prefs.repoName    = repoField.stringValue.trimmingCharacters(in: .whitespaces)
        window?.close()
        NotificationCenter.default.post(name: .settingsUpdated, object: nil)
    }

    @objc private func cancel() {
        window?.close()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let settingsUpdated = Notification.Name("com.github-actions-menu-bar.settingsUpdated")
}
