import Cocoa

/// Manages the NSStatusItem in the system menu bar.
///
/// - Shows 🟢 when every workflow's latest completed non-cancelled run succeeded.
/// - Shows 🔴 when at least one workflow's latest completed non-cancelled run failed.
/// - Shows ⚙️ when the app is not yet configured.
/// - Shows ⚠️ when a network / API error occurred.
/// - Refreshes every 60 seconds automatically.
class StatusBarController {
    private let statusItem: NSStatusItem
    private let apiClient: GitHubAPIClient
    private var refreshTimer: Timer?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        apiClient  = GitHubAPIClient()

        statusItem.button?.title = "⚙️"
        statusItem.button?.toolTip = "GitHub Actions Status"

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .settingsUpdated,
            object: nil
        )

        refresh()
        startTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Timer

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Refresh

    @objc private func settingsDidChange() {
        refresh()
    }

    @objc func refresh() {
        let prefs = UserPreferences.shared
        guard prefs.isConfigured else {
            DispatchQueue.main.async { self.renderNotConfiguredMenu() }
            return
        }

        apiClient.fetchWorkflowStatuses(
            owner: prefs.repoOwner,
            repo: prefs.repoName,
            token: prefs.githubToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let statuses): self?.renderWorkflowMenu(statuses)
                case .failure(let error):    self?.renderErrorMenu(error)
                }
            }
        }
    }

    // MARK: - Menu builders

    private func renderWorkflowMenu(_ statuses: [WorkflowStatus]) {
        let hasFailure = statuses.contains { $0.runStatus == .failure }
        let allSuccess = !statuses.isEmpty && statuses.allSatisfy { $0.runStatus == .success || $0.runStatus == .unknown }

        statusItem.button?.title = hasFailure ? "🔴" : (allSuccess ? "🟢" : "⚪")

        let menu = buildBaseMenu()

        if statuses.isEmpty {
            menu.insertItem(NSMenuItem(title: "No workflows found", action: nil, keyEquivalent: ""), at: 0)
        } else {
            var index = 0
            for status in statuses {
                let title = "\(status.runStatus.menuIndicator)  \(status.name)"
                let item  = NSMenuItem(title: title, action: #selector(openWorkflow(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = status
                menu.insertItem(item, at: index)
                index += 1
            }
        }

        menu.insertItem(NSMenuItem.separator(), at: menu.items.count - 3)
        statusItem.menu = menu
    }

    private func renderNotConfiguredMenu() {
        statusItem.button?.title = "⚙️"

        let menu = NSMenu()
        let configure = NSMenuItem(title: "Configure GitHub Actions Menu Bar…", action: #selector(openSettings), keyEquivalent: "")
        configure.target = self
        menu.addItem(configure)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem())

        statusItem.menu = menu
    }

    private func renderErrorMenu(_ error: Error) {
        statusItem.button?.title = "⚠️"

        let menu = buildBaseMenu()
        menu.insertItem(NSMenuItem(title: "Error: \(error.localizedDescription)", action: nil, keyEquivalent: ""), at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)

        statusItem.menu = menu
    }

    /// Returns a menu pre-populated with Refresh, Settings, and Quit items.
    private func buildBaseMenu() -> NSMenu {
        let menu = NSMenu()

        let refresh = NSMenuItem(title: "Refresh", action: #selector(self.refresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(quitItem())
        return menu
    }

    private func quitItem() -> NSMenuItem {
        NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    // MARK: - Actions

    @objc private func openWorkflow(_ sender: NSMenuItem) {
        guard let status = sender.representedObject as? WorkflowStatus,
              let url = status.htmlURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}
