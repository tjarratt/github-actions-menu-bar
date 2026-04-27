# GitHub Actions Menu Bar

A macOS menu-bar app that monitors every GitHub Actions workflow in a repository
and shows a colour-coded status indicator at a glance.

## Features

| Indicator | Meaning |
|-----------|---------|
| 🟢 | All workflows' latest completed runs succeeded |
| 🔴 | At least one workflow's latest completed run failed |
| ⚪ | No completed runs yet (or status unknown) |
| ⚙️ | App not yet configured |
| ⚠️ | Network / API error |

* Clicking the menu-bar icon shows a drop-down list of **every workflow** with its
  individual status indicator.
* Clicking a workflow item opens
  `https://github.com/<owner>/<repo>/actions/workflows/<filename>` in your browser.
* Cancelled runs are **ignored** – only `success`, `failure`, and `timed_out`
  conclusions are considered.
* Status refreshes automatically every **60 seconds**.

## Requirements

* macOS 13 Ventura or later
* Xcode 15 or later
* A GitHub Personal Access Token (classic) with the `repo` scope, **or** a
  fine-grained token with *Actions* read access for the target repository.

## Building

1. Open `GithubActionsMenuBar.xcodeproj` in Xcode.
2. Select the **GithubActionsMenuBar** scheme and your Mac as the run destination.
3. Press **⌘R** (or choose *Product ▸ Run*).

## Configuration

On first launch the menu shows **"Configure GitHub Actions Menu Bar…"**.
Click it to open the Settings window and fill in:

| Field | Example |
|-------|---------|
| GitHub Token | `ghp_xxxxxxxxxxxxxxxxxxxx` |
| Repository Owner | `octocat` |
| Repository Name | `hello-world` |

Your token is stored securely in the **macOS Keychain**; the owner and repo name
are stored in `UserDefaults`.

> **Tip:** create the token at <https://github.com/settings/tokens>
