import Foundation

// MARK: - View Models

enum MenuBarViewState {
    case notConfigured
    case error(String)
    case loaded(overallIcon: String, workflows: [WorkflowItemViewModel])
}

struct WorkflowItemViewModel {
    let id: Int
    let name: String
    let indicator: String
    let isAcknowledged: Bool
    let canAcknowledge: Bool
    let htmlURL: URL?
}

// MARK: - Store

class WorkflowStatusStore {
    private var lastStatuses: [WorkflowStatus] = []
    private var previousRunStatuses: [Int: WorkflowRunStatus] = [:]

    func update(statuses: [WorkflowStatus]) {
        let prefs = UserPreferences.shared
        var acknowledgedIDs = prefs.acknowledgedWorkflowIDs

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

        lastStatuses = statuses
    }

    func toggleAcknowledgement(id: Int) {
        let prefs = UserPreferences.shared
        var ids = prefs.acknowledgedWorkflowIDs
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        prefs.acknowledgedWorkflowIDs = ids
    }

    var viewState: MenuBarViewState {
        let acknowledgedIDs = UserPreferences.shared.acknowledgedWorkflowIDs

        let hasUnacknowledgedFailure = lastStatuses.contains {
            $0.runStatus == .failure && !acknowledgedIDs.contains($0.id)
        }

        let overallIcon: String
        if hasUnacknowledgedFailure {
            overallIcon = "🔴"
        } else if lastStatuses.isEmpty {
            overallIcon = "⚪"
        } else {
            overallIcon = "🟢"
        }

        let workflows = lastStatuses.map { status in
            WorkflowItemViewModel(
                id: status.id,
                name: status.name,
                indicator: status.runStatus.menuIndicator,
                isAcknowledged: status.runStatus == .failure && acknowledgedIDs.contains(status.id),
                canAcknowledge: status.runStatus == .failure,
                htmlURL: status.htmlURL
            )
        }

        return .loaded(overallIcon: overallIcon, workflows: workflows)
    }
}
