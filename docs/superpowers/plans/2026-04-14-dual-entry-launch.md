# Dual-Entry Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a standard macOS app host and a companion CLI so the project supports double-click GUI launch plus headless acceptance commands without duplicating business logic.

**Architecture:** Convert the package code into an importable `PhoneticsCore` library, add a checked-in Xcode app host that depends on that library, and replace the current executable-only launch shape with a `phoneticsctl` CLI that dispatches GUI and headless acceptance flows. Because the app host cannot exist without an importable module, the first implementation slice combines the spec's app-host and shared-core concerns into one PR.

**Tech Stack:** Swift 5.9, SwiftPM, Xcode macOS app target, SwiftUI, GRDB, XCTest, GitHub Actions, `gh`

**Plan-Specific Decision:** In the first implementation, `phoneticsctl --gui` resolves the app bundle path from `PHONETICS_APP_BUNDLE_PATH` first and falls back to a checked-in developer default only when present locally. Installed-app lookup is explicitly out of scope for this plan.

---

### Task 1: Create Importable Core And Standard App Host

**Files:**
- Modify: `Package.swift`
- Modify: `PhoneticsMaestro/App/RootView.swift`
- Delete: `PhoneticsMaestro/App/PhoneticsMaestroApp.swift`
- Create: `PhoneticsMaestroApp/PhoneticsMaestroApp.swift`
- Create: `PhoneticsMaestroApp/Info.plist`
- Create: `PhoneticsMaestro.xcodeproj/project.pbxproj`
- Create: `PhoneticsMaestro.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `PhoneticsMaestro.xcodeproj/xcshareddata/xcschemes/PhoneticsMaestroApp.xcscheme`

- [ ] **Step 1: Write the failing host verification**

Create a shell note in the PR description and task notes that the current host verification should fail before any code changes:

```bash
xcodebuild -project PhoneticsMaestro.xcodeproj -scheme PhoneticsMaestroApp -configuration Debug build
```

Expected: FAIL with "project 'PhoneticsMaestro.xcodeproj' does not exist".

- [ ] **Step 2: Run the failing host verification**

Run:

```bash
xcodebuild -project PhoneticsMaestro.xcodeproj -scheme PhoneticsMaestroApp -configuration Debug build
```

Expected: FAIL because the app host project has not been created yet.

- [ ] **Step 3: Convert the package target into an importable library**

Update `Package.swift` so package code is exported as `PhoneticsCore` and the library excludes the `@main` app entry:

```swift
products: [
    .library(name: "PhoneticsCore", targets: ["PhoneticsCore"])
],
targets: [
    .target(
        name: "PhoneticsCore",
        dependencies: [
            .product(name: "GRDB", package: "GRDB.swift")
        ],
        path: "PhoneticsMaestro",
        exclude: ["App/PhoneticsMaestroApp.swift"],
        resources: [
            .process("Resources")
        ],
        swiftSettings: [
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    ),
    .testTarget(
        name: "PhoneticsMaestroTests",
        dependencies: ["PhoneticsCore"],
        path: "PhoneticsMaestroTests",
        swiftSettings: [
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    )
]
```

- [ ] **Step 4: Move the app entry into a real app host**

Create `PhoneticsMaestroApp/PhoneticsMaestroApp.swift`:

```swift
import PhoneticsCore
import SwiftUI

@main
struct PhoneticsMaestroApp: App {
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task {
                    await viewModel.initialize()
                }
        }
        .defaultSize(width: 980, height: 640)
    }
}
```

Create `PhoneticsMaestroApp/Info.plist` with a real bundle identifier:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.apue.PhoneticsMaestro</string>
    <key>CFBundleName</key>
    <string>Phonetics Maestro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 5: Create the checked-in Xcode app project**

Create `PhoneticsMaestro.xcodeproj` so the `PhoneticsMaestroApp` target:

- builds the sources under `PhoneticsMaestroApp/`
- links the local package product `PhoneticsCore`
- embeds copied package resources through the package target
- produces `PhoneticsMaestro.app`
- has a shared `PhoneticsMaestroApp` scheme

The project file is verbose; use Xcode once to create it, then commit the generated `project.pbxproj`, workspace contents, and shared scheme.

- [ ] **Step 6: Run verification**

Run:

```bash
swift build
swift test
xcodebuild -project PhoneticsMaestro.xcodeproj -scheme PhoneticsMaestroApp -configuration Debug build
```

Expected: PASS. `swift test` still passes and `xcodebuild` now produces a real app bundle.

- [ ] **Step 7: Commit**

```bash
git add Package.swift \
  PhoneticsMaestro/App/RootView.swift \
  PhoneticsMaestroApp/PhoneticsMaestroApp.swift \
  PhoneticsMaestroApp/Info.plist \
  PhoneticsMaestro.xcodeproj
git commit -m "Add standard macOS app host"
```

### Task 2: Add `phoneticsctl` And GUI Dispatch

**Files:**
- Modify: `Package.swift`
- Create: `PhoneticsCLI/main.swift`
- Create: `PhoneticsCLI/CLICommand.swift`
- Create: `PhoneticsMaestro/Services/AppLauncher.swift`
- Modify: `Makefile`
- Create: `PhoneticsMaestroTests/AppLauncherTests.swift`

- [ ] **Step 1: Write the failing command verification**

Run:

```bash
swift run phoneticsctl --gui
```

Expected: FAIL with "no executable product named 'phoneticsctl'" before implementation.

- [ ] **Step 2: Add the CLI product and target**

Update `Package.swift` to expose both the shared library and a CLI executable:

```swift
products: [
    .library(name: "PhoneticsCore", targets: ["PhoneticsCore"]),
    .executable(name: "phoneticsctl", targets: ["phoneticsctl"])
],
targets: [
    .target(
        name: "PhoneticsCore",
        dependencies: [
            .product(name: "GRDB", package: "GRDB.swift")
        ],
        path: "PhoneticsMaestro",
        exclude: ["App/PhoneticsMaestroApp.swift"],
        resources: [
            .process("Resources")
        ],
        swiftSettings: [
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    ),
    .executableTarget(
        name: "phoneticsctl",
        dependencies: ["PhoneticsCore"],
        path: "PhoneticsCLI",
        swiftSettings: [
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    ),
    .testTarget(
        name: "PhoneticsMaestroTests",
        dependencies: ["PhoneticsCore"],
        path: "PhoneticsMaestroTests",
        swiftSettings: [
            .unsafeFlags(["-strict-concurrency=complete"])
        ]
    )
]
```

- [ ] **Step 3: Write a failing app-launcher test**

Create `PhoneticsMaestroTests/AppLauncherTests.swift`:

```swift
import XCTest
@testable import PhoneticsCore

final class AppLauncherTests: XCTestCase {
    func testGUICommandBuildsOpenArgumentsForAppBundle() {
        let launcher = AppLauncher(appPathProvider: { "/tmp/PhoneticsMaestro.app" })
        XCTAssertEqual(try launcher.guiLaunchCommand(), ["/usr/bin/open", "/tmp/PhoneticsMaestro.app"])
    }
}
```

- [ ] **Step 4: Run the failing launcher test**

Run:

```bash
swift test --filter AppLauncherTests
```

Expected: FAIL because `AppLauncher` does not exist yet.

- [ ] **Step 5: Implement the GUI dispatch path**

Create `PhoneticsCLI/CLICommand.swift`:

```swift
enum CLICommand: Equatable {
    case gui
    case headless(HeadlessAcceptanceCommand)
}
```

Create `PhoneticsMaestro/Services/AppLauncher.swift`:

```swift
import Foundation

enum AppLauncherError: Error {
    case bundlePathNotConfigured
}

struct AppLauncher {
    let appPathProvider: @Sendable () throws -> String

    init(appPathProvider: @escaping @Sendable () throws -> String = {
        if let override = ProcessInfo.processInfo.environment["PHONETICS_APP_BUNDLE_PATH"] {
            return override
        }

        let fallback = FileManager.default.currentDirectoryPath + "/DerivedData/Build/Products/Debug/PhoneticsMaestro.app"
        if FileManager.default.fileExists(atPath: fallback) {
            return fallback
        }

        throw AppLauncherError.bundlePathNotConfigured
    }) {
        self.appPathProvider = appPathProvider
    }

    func guiLaunchCommand() throws -> [String] {
        ["/usr/bin/open", try appPathProvider()]
    }
}
```

Create `PhoneticsCLI/main.swift`:

```swift
import Foundation
import PhoneticsCore

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    switch arguments {
    case ["--gui"]:
        let launcher = AppLauncher()
        let command = try launcher.guiLaunchCommand()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        try process.run()
        process.waitUntilExit()
        exit(process.terminationStatus)
    default:
        fputs("Usage: phoneticsctl --gui | phoneticsctl --headless <command>\\n", stderr)
        exit(1)
    }
} catch {
    fputs("\\(error)\\n", stderr)
    exit(1)
}
```

- [ ] **Step 6: Run verification**

Run:

```bash
swift build
swift test --filter AppLauncherTests
swift run phoneticsctl --gui
```

Expected: library and CLI build; launcher test passes; GUI command attempts to open the built app bundle.

- [ ] **Step 7: Commit**

```bash
git add Package.swift \
  PhoneticsCLI \
  PhoneticsMaestro/Services/AppLauncher.swift \
  PhoneticsMaestroTests/AppLauncherTests.swift \
  Makefile
git commit -m "Add GUI launch CLI"
```

### Task 3: Add Headless Acceptance Commands

**Files:**
- Create: `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`
- Create: `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift`
- Modify: `PhoneticsCLI/CLICommand.swift`
- Modify: `PhoneticsCLI/main.swift`
- Create: `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`

- [ ] **Step 1: Write the failing headless tests**

Create `PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift`:

```swift
import XCTest
@testable import PhoneticsCore

final class HeadlessAcceptanceRunnerTests: XCTestCase {
    func testSeedCheckReportsNonZeroSeedCounts() async throws
    func testDBSummaryIncludesCountsAndDatabasePath() async throws
    func testSmokeTestExercisesCoreQueries() async throws
}
```

Use the same in-memory or temporary-directory setup pattern already used by `DataServiceTests`.

- [ ] **Step 2: Run the failing tests**

Run:

```bash
swift test --filter HeadlessAcceptanceRunnerTests
```

Expected: FAIL because no headless runner exists yet.

- [ ] **Step 3: Implement runner types in the shared core**

Create `PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift`:

```swift
enum HeadlessAcceptanceCommand: String, Equatable {
    case seedCheck = "seed-check"
    case dbSummary = "db-summary"
    case smokeTest = "smoke-test"
}
```

Create `PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift` with async methods that:

- initialize `DataService`
- read pair and sentence counts
- fetch one training pair
- fetch history summaries
- fetch settings
- return compact plain-text output plus success/failure status

The runner should not call audio APIs.

- [ ] **Step 4: Wire the CLI to `--headless`**

Update `PhoneticsCLI/CLICommand.swift`:

```swift
enum CLICommand: Equatable {
    case gui
    case headless(HeadlessAcceptanceCommand)
}
```

Update `PhoneticsCLI/main.swift` to parse:

```swift
case ["--headless", "seed-check"]
case ["--headless", "db-summary"]
case ["--headless", "smoke-test"]
```

and print runner output to stdout with non-zero exit on failure.

- [ ] **Step 5: Run verification**

Run:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless db-summary
swift run phoneticsctl --headless smoke-test
```

Expected: PASS. The three commands complete successfully and print stable summaries.

- [ ] **Step 6: Commit**

```bash
git add PhoneticsMaestro/Services/HeadlessAcceptanceCommand.swift \
  PhoneticsMaestro/Services/HeadlessAcceptanceRunner.swift \
  PhoneticsCLI/CLICommand.swift \
  PhoneticsCLI/main.swift \
  PhoneticsMaestroTests/HeadlessAcceptanceRunnerTests.swift
git commit -m "Add headless acceptance commands"
```

### Task 4: Integrate CI, Developer Workflow, And Handoff

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `README.md`
- Modify: `Makefile`
- Modify: `AGENTS.md`
- Create: `docs/handoff-2026-04-14-$(date +%H%M)-codex.md`

- [ ] **Step 1: Write the failing CI expectation**

Record that the current workflow does not run headless verification:

```bash
gh workflow view CI --yaml
```

Expected: current YAML contains only `swift build` and `swift test`.

- [ ] **Step 2: Update developer commands and CI**

Modify `.github/workflows/ci.yml` to add:

```yaml
      - name: Headless Seed Check
        run: swift run phoneticsctl --headless seed-check

      - name: Headless Smoke Test
        run: swift run phoneticsctl --headless smoke-test
```

Modify `Makefile`:

```make
headless-seed-check:
	swift run phoneticsctl --headless seed-check

headless-smoke-test:
	swift run phoneticsctl --headless smoke-test
```

Update `README.md` and `AGENTS.md` so the standard verification chain includes:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
```

- [ ] **Step 3: Run verification**

Run:

```bash
swift build
swift test
swift run phoneticsctl --headless seed-check
swift run phoneticsctl --headless smoke-test
xcodebuild -project PhoneticsMaestro.xcodeproj -scheme PhoneticsMaestroApp -configuration Debug build
```

Expected: PASS on the implementation branch before opening the final PR.

- [ ] **Step 4: Write handoff note**

Create `docs/handoff-2026-04-14-$(date +%H%M)-codex.md` capturing:

- merged PR numbers for the dual-entry work
- current `main` SHA
- standard GUI launch path
- standard headless verification path
- residual risk that installed-app discovery is still out of scope for `phoneticsctl --gui`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml \
  README.md \
  Makefile \
  AGENTS.md \
  docs/handoff-2026-04-14-$(date +%H%M)-codex.md
git commit -m "Document dual-entry launch workflow"
```

## Self-Review

- Spec coverage:
  - Standard app bundle: Task 1
  - Shared core: Task 1
  - `phoneticsctl --gui`: Task 2
  - `seed-check`, `db-summary`, `smoke-test`: Task 3
  - docs and CI integration: Task 4
- Placeholder scan:
  - No `TODO` or `TBD` markers remain.
  - The only generated artifact step is the Xcode project file, which is explicit about what must be committed.
- Type consistency:
  - Shared library name is `PhoneticsCore`.
  - CLI executable name is `phoneticsctl`.
  - Headless enum name is `HeadlessAcceptanceCommand`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-14-dual-entry-launch.md`.

Execution mode is already chosen by the user: Subagent-Driven loop with per-slice PR/test/review/fix/merge.
