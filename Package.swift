// swift-tools-version: 5.9
// PhotoSweepLogic — the pure-logic package, runnable on Linux CI.
//
// The scan math (similarity, grouping, keeper picking, storage
// estimates) lives in PhotoSweep/Logic as Foundation-only Swift with
// zero SwiftUI / SwiftData / PhotoKit / Vision imports, so it can be
// tested on Linux without a Mac. This Package.swift exposes exactly
// that directory as a library and runs the mirror test suite in
// LinuxTests/.
//
// The Xcode test target (Tests/) runs the same assertions against the
// app target via @testable import PhotoSweep. Keep the two suites in
// sync: LinuxTests import PhotoSweepLogic, Tests import PhotoSweep —
// the test bodies are otherwise identical.
import PackageDescription

let package = Package(
    name: "PhotoSweepLogic",
    products: [
        .library(name: "PhotoSweepLogic", targets: ["PhotoSweepLogic"]),
    ],
    targets: [
        .target(
            name: "PhotoSweepLogic",
            path: "PhotoSweep/Logic"
        ),
        .testTarget(
            name: "PhotoSweepLogicTests",
            dependencies: ["PhotoSweepLogic"],
            path: "LinuxTests"
        ),
    ]
)
