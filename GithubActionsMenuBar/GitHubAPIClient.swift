import Foundation

/// Fetches workflow and run data from the GitHub Actions REST API.
class GitHubAPIClient {
    private let baseURL = "https://api.github.com"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetches all workflows for `owner/repo` and resolves the status of each
    /// based on its most-recent *completed, non-cancelled* run.
    func fetchWorkflowStatuses(
        owner: String,
        repo: String,
        token: String,
        completion: @escaping (Result<[WorkflowStatus], Error>) -> Void
    ) {
        fetchWorkflowList(owner: owner, repo: repo, token: token) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let workflows):
                self?.resolveStatuses(
                    workflows: workflows,
                    owner: owner,
                    repo: repo,
                    token: token,
                    completion: completion
                )
            }
        }
    }

    // MARK: - Private helpers

    private func resolveStatuses(
        workflows: [WorkflowInfo],
        owner: String,
        repo: String,
        token: String,
        completion: @escaping (Result<[WorkflowStatus], Error>) -> Void
    ) {
        guard !workflows.isEmpty else {
            completion(.success([]))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var statuses: [WorkflowStatus] = []
        var firstError: Error?

        for workflow in workflows {
            group.enter()
            fetchLatestRun(
                workflowID: workflow.id,
                owner: owner,
                repo: repo,
                token: token
            ) { runResult in
                defer { group.leave() }
                lock.withLock {
                    switch runResult {
                    case .success(let run):
                        let url = URL(string: "https://github.com/\(owner)/\(repo)/actions/workflows/\(workflow.filename)")
                        let status = WorkflowStatus(
                            id: workflow.id,
                            name: workflow.name,
                            path: workflow.path,
                            runStatus: WorkflowRunStatus(conclusion: run?.conclusion),
                            htmlURL: url
                        )
                        statuses.append(status)
                    case .failure(let error):
                        if firstError == nil { firstError = error }
                    }
                }
            }
        }

        group.notify(queue: .global()) {
            if let error = firstError {
                completion(.failure(error))
            } else {
                completion(.success(statuses.sorted { $0.name < $1.name }))
            }
        }
    }

    private func fetchWorkflowList(
        owner: String,
        repo: String,
        token: String,
        completion: @escaping (Result<[WorkflowInfo], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/workflows?per_page=100") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "GET"

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.noData))
                return
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.httpError(httpResponse.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WorkflowsResponse.self, from: data)
                completion(.success(decoded.workflows))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    /// Fetches completed runs for `workflowID`, returning the first that is
    /// not cancelled (i.e. either success, failure, timed_out, etc.).
    private func fetchLatestRun(
        workflowID: Int,
        owner: String,
        repo: String,
        token: String,
        completion: @escaping (Result<WorkflowRun?, Error>) -> Void
    ) {
        // status=completed excludes in_progress / queued runs
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/actions/workflows/\(workflowID)/runs?per_page=10&status=completed") else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = authorizedRequest(url: url, token: token)
        request.httpMethod = "GET"

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.noData))
                return
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.httpError(httpResponse.statusCode)))
                return
            }
            guard let data else {
                completion(.failure(APIError.noData))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
                // Skip cancelled runs; return the most-recent actionable run
                let run = decoded.workflow_runs.first { $0.conclusion != "cancelled" }
                completion(.success(run))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:    return "Invalid URL"
            case .noData:        return "No data received from server"
            case .httpError(let code): return "HTTP \(code) error"
            }
        }
    }
}
