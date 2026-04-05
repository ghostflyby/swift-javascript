# Swift JavaScriptCore
JavaScriptCore Swift wrapper that directly wraps the C API when possible,
while exposing Swift-specific surfaces such as `Actor` and `~Copyable`.

## Implementation Principles
1. Wrap the C API when possible.
2. Keep engine-agnostic logic in `Sources/SwiftJavaScript`.
3. Keep `Sources/SwiftyJavaScriptCore` focused on JavaScriptCore-specific bridge code.

## Migration Guidelines
1. When migrating a file, move engine-agnostic declarations and logic to core first.
2. Keep JavaScriptCore-specific callback wiring, raw ref handling, and class/runtime bridging in facade/backend.
3. After migration, reduce facade to thin wrappers or typealias only when still needed.
4. Remove redundant JSC-only typealias files when symbols are already available from core exports.

## TODO Workflow
1. Maintain `TODO.md` with sectioned checklists.
2. Update an in-progress item before implementing.
3. Mark a TODO item as done immediately after completion.
4. Keep TODO focused on C API parity and core/facade migration progress; do not include ObjC bridging goals unless explicitly requested.

## Testing
1. Use `swift test`.
2. Do not use XCTest.
3. For protocol changes, update mock/test engine witnesses in core tests.
4. Run the full test suite after each migration slice.

## Code Style
1. Run `swift format` for modified `.swift` files.
2. Do not run `swift format` on Markdown files such as `TODO.md`.