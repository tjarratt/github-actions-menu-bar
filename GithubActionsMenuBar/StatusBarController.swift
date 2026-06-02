import Cocoa

/// Manages the NSStatusItem in the system menu bar.
///
/// - Shows 🟢 when every workflow's latest completed non-cancelled run succeeded,
///   OR when all failures have been acknowledged.
/// - Shows 🔴 when at least one workflow has an unacknowledged failure.
/// - Shows ⚙️ when the app is not yet configured.
/// - Shows ⚠️ when a network / API error occurred.
/// - Refreshes every 60 seconds automatically.
class StatusBarController {
    private let statusItem: NSStatusItem
    private let apiClient: GitHubAPIClient
    private var refreshTimer: Timer?

    /// Last raw statuses from the API, used to re-render without a network fetch.
    private var lastFetchedStatuses: [WorkflowStatus] = []
    /// Previous run status per workflow ID, used to detect newly-red builds.
    private var previousRunStatuses: [Int: WorkflowRunStatus] = [:]

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
        lastFetchedStatuses = statuses

        let prefs = UserPreferences.shared
        var acknowledgedIDs = prefs.acknowledgedWorkflowIDs

        // Auto-reset acknowledgment for workflows that newly became red.
        for status in statuses {
            if status.runStatus == .failure {
                if previousRunStatuses[status.id] != .failure {
                    acknowledgedIDs.remove(status.id)
                }
            } else {
                acknowledgedIDs.remove(status.id)
            }
        }
        prefs.acknowledgedWorkflowIDs = acknowledgedIDs

        for status in statuses {
            previousRunStatuses[status.id] = status.runStatus
        }

        let hasUnacknowledgedFailure = statuses.contains {
            $0.runStatus == .failure && !acknowledgedIDs.contains($0.id)
        }
        statusItem.button?.title = hasUnacknowledgedFailure ? "🔴" : (statuses.isEmpty ? "⚪" : "🟢")

        let menu = buildBaseMenu()

        if statuses.isEmpty {
            menu.insertItem(NSMenuItem(title: "No workflows found", action: nil, keyEquivalent: ""), at: 0)
        } else {
            for (index, status) in statuses.enumerated() {
                let item = buildWorkflowMenuItem(status, acknowledgedIDs: acknowledgedIDs)
                menu.insertItem(item, at: index)
            }
        }

        menu.insertItem(NSMenuItem.separator(), at: menu.items.count - 3)
        statusItem.menu = menu
    }

    private func buildWorkflowMenuItem(_ status: WorkflowStatus, acknowledgedIDs: Set<Int>) -> NSMenuItem {
        let isAcknowledged = status.runStatus == .failure && acknowledgedIDs.contains(status.id)
        let acknowledgementIndicator = isAcknowledged ? " 👀" : ""
        let title = "\(status.runStatus.menuIndicator)  \(acknowledgementIndicator)\(status.name)"

        guard status.runStatus == .failure else {
            let item = NSMenuItem(title: title, action: #selector(openWorkflow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = status
            return item
        }

        // Failing workflow: submenu with Open + Acknowledge toggle.
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let openItem = NSMenuItem(title: "Open in Browser", action: #selector(openWorkflow(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = status
        submenu.addItem(openItem)

        submenu.addItem(NSMenuItem.separator())

        let ackItem = NSMenuItem(title: "Acknowledged", action: #selector(toggleAcknowledgement(_:)), keyEquivalent: "")
        ackItem.target = self
        ackItem.representedObject = status
        ackItem.state = acknowledgedIDs.contains(status.id) ? .on : .off
        submenu.addItem(ackItem)

        item.submenu = submenu
        return item
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

    @objc private func toggleAcknowledgement(_ sender: NSMenuItem) {
        guard let status = sender.representedObject as? WorkflowStatus else { return }
        let prefs = UserPreferences.shared
        var ids = prefs.acknowledgedWorkflowIDs
        if ids.contains(status.id) {
            ids.remove(status.id)
        } else {
            ids.insert(status.id)
        }
        prefs.acknowledgedWorkflowIDs = ids
        renderWorkflowMenu(lastFetchedStatuses)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}
