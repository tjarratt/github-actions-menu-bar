import Foundation

// MARK: - GitHub API Response Models

struct WorkflowsResponse: Decodable {
    let total_count: Int
    let workflows: [WorkflowInfo]
}

struct WorkflowInfo: Decodable {
    let id: Int
    let name: String
    let path: String

    /// The bare filename extracted from `.github/workflows/<filename>`
    var filename: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

struct WorkflowRunsResponse: Decodable {
    let total_count: Int
    let workflow_runs: [WorkflowRun]
}

struct WorkflowRun: Decodable {
    let id: Int
    let status: String
    let conclusion: String?
    let html_url: String
}

// MARK: - UI Model

/// The conclusion status of a single workflow's most-recent completed run.
enum WorkflowRunStatus: Equatable {
    case success
    case failure
    case unknown

    /// Emoji indicator shown next to the workflow name in the menu.
    var menuIndicator: String {
        switch self {
        case .success: return "🟢"
        case .failure: return "🔴"
        case .unknown: return "⚪"
        }
    }

    init(conclusion: String?) {
        guard let conclusion else {
            self = .unknown
            return
        }
        switch conclusion.lowercased() {
        case "success":
            self = .success
        case "failure", "timed_out", "startup_failure":
            self = .failure
        default:
            self = .unknown
        }
    }
}

struct WorkflowStatus {
    let id: Int
    let name: String
    let path: String
    let runStatus: WorkflowRunStatus
    /// Direct link to the workflow's page on GitHub.
    let htmlURL: URL?
}
