import Quick
import Nimble
@testable import GithubActionsMenuBar

// MARK: - Encodable stand-ins for stubbing API responses

private struct WorkflowsPayload: Encodable {
    let total_count: Int
    let workflows: [WorkflowPayload]
}

private struct WorkflowPayload: Encodable {
    let id: Int
    let name: String
    let path: String
}

private struct RunsPayload: Encodable {
    let total_count: Int
    let workflow_runs: [RunPayload]
}

private struct RunPayload: Encodable {
    let id: Int
    let status: String
    let conclusion: String?
    let html_url: String
}

// MARK: - Spec

final class GitHubAPIClientSpec: QuickSpec {
    override class func spec() {

        var client: GitHubAPIClient!

        beforeEach {
            MockURLProtocol.requestHandler = nil
            client = GitHubAPIClient(session: MockURLProtocol.makeSession())
        }

        afterEach {
            MockURLProtocol.requestHandler = nil
        }

        describe("fetchWorkflowStatuses(owner:repo:token:completion:)") {

            context("when the workflow list and all run endpoints succeed") {
                it("returns WorkflowStatus values sorted alphabetically by name") {
                    let workflows = WorkflowsPayload(
                        total_count: 2,
                        workflows: [
                            WorkflowPayload(id: 1, name: "Zebra", path: ".github/workflows/zebra.yml"),
                            WorkflowPayload(id: 2, name: "Alpha", path: ".github/workflows/alpha.yml")
                        ]
                    )
                    let successRuns = RunsPayload(
                        total_count: 1,
                        workflow_runs: [RunPayload(id: 10, status: "completed", conclusion: "success", html_url: "")]
                    )
                    let failureRuns = RunsPayload(
                        total_count: 1,
                        workflow_runs: [RunPayload(id: 20, status: "completed", conclusion: "failure", html_url: "")]
                    )

                    MockURLProtocol.requestHandler = { request in
                        let path = request.url?.path ?? ""
                        if path.hasSuffix("/actions/workflows") {
                            return try MockURLProtocol.makeResponse(body: workflows)
                        } else if path.contains("/workflows/1/") {
                            return try MockURLProtocol.makeResponse(body: successRuns)
                        } else {
                            return try MockURLProtocol.makeResponse(body: failureRuns)
                        }
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { result in
                            guard case .success(let statuses) = result else {
                                fail("Expected success but got \(result)")
                                done()
                                return
                            }
                            expect(statuses).to(haveCount(2))
                            expect(statuses[0].name).to(equal("Alpha"))
                            expect(statuses[0].runStatus).to(equal(.failure))
                            expect(statuses[1].name).to(equal("Zebra"))
                            expect(statuses[1].runStatus).to(equal(.success))
                            done()
                        }
                    }
                }
            }

            context("when there are no workflows") {
                it("returns an empty array") {
                    let empty = WorkflowsPayload(total_count: 0, workflows: [])
                    MockURLProtocol.requestHandler = { _ in
                        try MockURLProtocol.makeResponse(body: empty)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { result in
                            guard case .success(let statuses) = result else {
                                fail("Expected success but got \(result)")
                                done()
                                return
                            }
                            expect(statuses).to(beEmpty())
                            done()
                        }
                    }
                }
            }

            context("when the workflow list endpoint returns a non-2xx status") {
                it("returns a .httpError failure") {
                    MockURLProtocol.requestHandler = { _ in
                        MockURLProtocol.makeResponse(statusCode: 401)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { result in
                            guard case .failure(let error as GitHubAPIClient.APIError) = result else {
                                fail("Expected APIError but got \(result)")
                                done()
                                return
                            }
                            expect(error).to(equal(.httpError(401)))
                            done()
                        }
                    }
                }
            }

            context("when the most-recent run is cancelled") {
                it("skips the cancelled run and uses the next non-cancelled one") {
                    let workflows = WorkflowsPayload(
                        total_count: 1,
                        workflows: [WorkflowPayload(id: 1, name: "CI", path: ".github/workflows/ci.yml")]
                    )
                    let runs = RunsPayload(
                        total_count: 2,
                        workflow_runs: [
                            RunPayload(id: 1, status: "completed", conclusion: "cancelled", html_url: ""),
                            RunPayload(id: 2, status: "completed", conclusion: "success", html_url: "")
                        ]
                    )

                    MockURLProtocol.requestHandler = { request in
                        let path = request.url?.path ?? ""
                        if path.contains("/runs") {
                            return try MockURLProtocol.makeResponse(body: runs)
                        }
                        return try MockURLProtocol.makeResponse(body: workflows)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { result in
                            guard case .success(let statuses) = result else {
                                fail("Expected success but got \(result)")
                                done()
                                return
                            }
                            expect(statuses).to(haveCount(1))
                            expect(statuses[0].runStatus).to(equal(.success))
                            done()
                        }
                    }
                }
            }

            context("when a workflow has no completed runs") {
                it("reports .unknown for that workflow") {
                    let workflows = WorkflowsPayload(
                        total_count: 1,
                        workflows: [WorkflowPayload(id: 1, name: "CI", path: ".github/workflows/ci.yml")]
                    )
                    let emptyRuns = RunsPayload(total_count: 0, workflow_runs: [])

                    MockURLProtocol.requestHandler = { request in
                        let path = request.url?.path ?? ""
                        if path.contains("/runs") {
                            return try MockURLProtocol.makeResponse(body: emptyRuns)
                        }
                        return try MockURLProtocol.makeResponse(body: workflows)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { result in
                            guard case .success(let statuses) = result else {
                                fail("Expected success but got \(result)")
                                done()
                                return
                            }
                            expect(statuses).to(haveCount(1))
                            expect(statuses[0].runStatus).to(equal(.unknown))
                            done()
                        }
                    }
                }
            }

            context("when authorizing requests") {
                it("sends a Bearer token in the Authorization header") {
                    var capturedRequest: URLRequest?
                    let empty = WorkflowsPayload(total_count: 0, workflows: [])

                    MockURLProtocol.requestHandler = { request in
                        capturedRequest = request
                        return try MockURLProtocol.makeResponse(body: empty)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "my-token") { _ in
                            done()
                        }
                    }

                    expect(capturedRequest?.value(forHTTPHeaderField: "Authorization")).to(equal("Bearer my-token"))
                }

                it("sets the GitHub v3 Accept header") {
                    var capturedRequest: URLRequest?
                    let empty = WorkflowsPayload(total_count: 0, workflows: [])

                    MockURLProtocol.requestHandler = { request in
                        capturedRequest = request
                        return try MockURLProtocol.makeResponse(body: empty)
                    }

                    waitUntil(timeout: .seconds(5)) { done in
                        client.fetchWorkflowStatuses(owner: "o", repo: "r", token: "t") { _ in
                            done()
                        }
                    }

                    expect(capturedRequest?.value(forHTTPHeaderField: "Accept"))
                        .to(equal("application/vnd.github.v3+json"))
                }
            }
        }
    }
}
