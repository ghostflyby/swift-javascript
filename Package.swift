// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftyJavaScriptCore",
  platforms: [
    // 15.4 floor: `isolated deinit` (SE-0371) requires macOS 15.4 runtime.
    .macOS("15.4")
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "SwiftJavaScript",
      targets: ["SwiftJavaScript"]),
    .library(
      name: "SwiftyJavaScriptCore",
      targets: ["SwiftyJavaScriptCore"]),
    .library(
      name: "SwiftyQuickJS",
      targets: ["SwiftyQuickJS"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/ghostflyby/Swift-CQuickJS", from: "0.14.0-pack.1"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "SwiftJavaScript",
      swiftSettings: [
        // `isolated deinit` (SE-0371) runs JSContext's destructor on the
        // actor's dedicated VM thread, so the default-scope drain
        // (JSValueUnprotect / JS_FreeValue) never touches the engine from
        // a foreign thread. Tracked in TODO 2.5 until the feature ships.
        .enableExperimentalFeature("IsolatedDeinit")
      ]
    ),
    .target(
      name: "SwiftyJavaScriptCore",
      dependencies: [
        "SwiftJavaScript",
        "SwiftyJavaScriptCoreMacrosPlugin",
      ]
    ),
    .target(
      name: "SwiftyQuickJS",
      dependencies: [
        "SwiftJavaScript",
        .product(name: "CQuickJSStatic", package: "Swift-CQuickJS"),
      ]
    ),
    .macro(
      name: "SwiftyJavaScriptCoreMacrosPlugin",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "SwiftJavaScriptTests",
      dependencies: [
        "SwiftJavaScript"
      ]
    ),
    .testTarget(
      name: "SwiftJavaScriptEngineTests",
      dependencies: [
        "SwiftJavaScript",
        "SwiftyJavaScriptCore",
        "SwiftyQuickJS",
      ]
    ),
    .testTarget(
      name: "SwiftyJavaScriptCoreTests",
      dependencies: [
        "SwiftyJavaScriptCore",
        "SwiftyJavaScriptCoreMacrosPlugin",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "SwiftyQuickJSTests",
      dependencies: [
        "SwiftyQuickJS"
      ]
    ),
  ]
)
