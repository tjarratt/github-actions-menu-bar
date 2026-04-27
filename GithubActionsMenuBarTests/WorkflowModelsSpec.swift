import Quick
import Nimble
@testable import GithubActionsMenuBar

final class WorkflowModelsSpec: QuickSpec {
    override class func spec() {

        // MARK: - WorkflowRunStatus

        describe("WorkflowRunStatus") {

            describe("init(conclusion:)") {
                it("maps 'success' to .success") {
                    expect(WorkflowRunStatus(conclusion: "success")).to(equal(.success))
                }

                it("maps 'failure' to .failure") {
                    expect(WorkflowRunStatus(conclusion: "failure")).to(equal(.failure))
                }

                it("maps 'timed_out' to .failure") {
                    expect(WorkflowRunStatus(conclusion: "timed_out")).to(equal(.failure))
                }

                it("maps 'startup_failure' to .failure") {
                    expect(WorkflowRunStatus(conclusion: "startup_failure")).to(equal(.failure))
                }

                it("maps 'cancelled' to .unknown") {
                    expect(WorkflowRunStatus(conclusion: "cancelled")).to(equal(.unknown))
                }

                it("maps nil to .unknown") {
                    expect(WorkflowRunStatus(conclusion: nil)).to(equal(.unknown))
                }

                it("maps an unrecognised conclusion to .unknown") {
                    expect(WorkflowRunStatus(conclusion: "skipped")).to(equal(.unknown))
                }

                it("is case-insensitive") {
                    expect(WorkflowRunStatus(conclusion: "SUCCESS")).to(equal(.success))
                    expect(WorkflowRunStatus(conclusion: "Failure")).to(equal(.failure))
                    expect(WorkflowRunStatus(conclusion: "TIMED_OUT")).to(equal(.failure))
                }
            }

            describe("menuIndicator") {
                it("returns 🟢 for .success") {
                    expect(WorkflowRunStatus.success.menuIndicator).to(equal("🟢"))
                }

                it("returns 🔴 for .failure") {
                    expect(WorkflowRunStatus.failure.menuIndicator).to(equal("🔴"))
                }

                it("returns ⚪ for .unknown") {
                    expect(WorkflowRunStatus.unknown.menuIndicator).to(equal("⚪"))
                }
            }
        }

        // MARK: - WorkflowInfo

        describe("WorkflowInfo") {
            describe("filename") {
                it("extracts the filename from a .github/workflows path") {
                    let info = WorkflowInfo(id: 1, name: "CI", path: ".github/workflows/ci.yml")
                    expect(info.filename).to(equal("ci.yml"))
                }

                it("extracts a .yaml extension correctly") {
                    let info = WorkflowInfo(id: 2, name: "Deploy", path: ".github/workflows/deploy.yaml")
                    expect(info.filename).to(equal("deploy.yaml"))
                }

                it("handles a bare filename with no directory component") {
                    let info = WorkflowInfo(id: 3, name: "Test", path: "test.yml")
                    expect(info.filename).to(equal("test.yml"))
                }
            }
        }
    }
}
