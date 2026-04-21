# 清理与基线完成项

归档自 `TODO.md` 中已经完成的 JavaScriptCore 导入消除基线与 helper 清理工作。

## JavaScriptCore 导入消除基线

### 当前基线（2026-03-14）

- [x] `Sources/**/*.swift` 中 `import JavaScriptCore` 目标清单已清零
- [x] backend 适配层保留导入基线已确认
- [x] 需在重构中彻底消除导入的目标清单已清零

### 阶段性指标

- [x] 指标A：目标清单文件中的 `import JavaScriptCore` 数量从 `1` 降到 `0`
- [x] 指标B：每次减少导入后保持 `swift build --build-tests` 通过
- [x] 指标C：每次减少导入后保持 `swift test` 全量通过

## 无用 Helper 清理

- [x] 清理 `JavaScriptCoreBackendDriver` 中短小一次性 fallback helper
- [x] 清理 `JSClassValueConvertible` 内部同类短 helper
- [x] 清理 `JSClass` / `JSClassValueConvertible` 的纯转发 helper
- [x] 清理后执行 `swift build --build-tests` + `swift test` 并按单独 cleanup commit 收口
