import Cocoa

class StatusBarController {
    private let statusItem: NSStatusItem
    private let apiClient: GitHubAPIClient
    private let store = WorkflowStatusStore()
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
            DispatchQueue.main.async { self.renderMenu(.notConfigured) }
            return
        }

        apiClient.fetchWorkflowStatuses(
            owner: prefs.repoOwner,
            repo: prefs.repoName,
            token: prefs.githubToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let statuses):
                    self.store.update(statuses: statuses)
                    self.renderMenu(self.store.viewState)
                case .failure(let error):
                    self.renderMenu(.error(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Rendering

    private func renderMenu(_ state: MenuBarViewState) {
        switch state {
        case .notConfigured:
            renderNotConfiguredMenu()
        case .error(let message):
            renderErrorMenu(message)
        case .loaded(let overallIcon, let workflows):
            renderWorkflowMenu(overallIcon: overallIcon, workflows: workflows)
        }
    }

    private func renderWorkflowMenu(overallIcon: String, workflows: [WorkflowItemViewModel]) {
        statusItem.button?.title = overallIcon

        let menu = buildBaseMenu()

        if workflows.isEmpty {
            menu.insertItem(NSMenuItem(title: "No workflows found", action: nil, keyEquivalent: ""), at: 0)
        } else {
            for (index, workflow) in workflows.enumerated() {
                menu.insertItem(buildWorkflowMenuItem(workflow), at: index)
            }
        }

        menu.insertItem(NSMenuItem.separator(), at: menu.items.count - 3)
        statusItem.menu = menu
    }

    private func buildWorkflowMenuItem(_ viewModel: WorkflowItemViewModel) -> NSMenuItem {
        let acknowledgementIndicator = viewModel.isAcknowledged ? " 👀" : ""
        let title = "\(viewModel.indicator)  \(acknowledgementIndicator)\(viewModel.name)"

        guard viewModel.canAcknowledge else {
            let item = NSMenuItem(title: title, action: #selector(openWorkflow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = viewModel
            return item
        }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let openItem = NSMenuItem(title: "Open in Browser", action: #selector(openWorkflow(_:)), keyEquivalent: "")
        openItem.target = self
        openItem.representedObject = viewModel
        submenu.addItem(openItem)

        submenu.addItem(NSMenuItem.separator())

        let ackItem = NSMenuItem(title: "Acknowledge", action: #selector(toggleAcknowledgement(_:)), keyEquivalent: "")
        ackItem.target = self
        ackItem.representedObject = viewModel
        ackItem.state = viewModel.isAcknowledged ? .on : .off
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

    private func renderErrorMenu(_ message: String) {
        statusItem.button?.title = "⚠️"

        let menu = buildBaseMenu()
        menu.insertItem(NSMenuItem(title: "Error: \(message)", action: nil, keyEquivalent: ""), at: 0)
        menu.insertItem(NSMenuItem.separator(), at: 1)

        statusItem.menu = menu
    }

    private func buildBaseMenu() -> NSMenu {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(self.refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

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
        guard let viewModel = sender.representedObject as? WorkflowItemViewModel,
              let url = viewModel.htmlURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleAcknowledgement(_ sender: NSMenuItem) {
        guard let viewModel = sender.representedObject as? WorkflowItemViewModel else { return }
        store.toggleAcknowledgement(id: viewModel.id)
        renderMenu(store.viewState)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }
}
