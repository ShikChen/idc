# 專案開發指南 (AGENTS.md)

## Commit 規範

- 所有 commit 必須符合 Conventional Commits（例如：`feat: ...`、`fix: ...`、`docs: ...`、`test: ...`）
- commit message 必須包含 body，且以 bullet points 描述本次變更內容

## 測試與格式化

- iOS 測試預設 destination：`platform=iOS Simulator,name=iPhone Air`
- 標準測試指令：`set -o pipefail; xcodebuild test -scheme idc-server -destination 'platform=iOS Simulator,name=iPhone Air' | xcbeautify`
- 跑 iOS 測試請用 `xcodebuild test ... | xcbeautify`（記得加 `set -o pipefail` 以保留正確 exit code）
- 需要整理格式時，請在 repo 根目錄執行 `swiftformat .`（Swift 版本為 5.0）

## 注意事項

- `CLAUDE.md` 和 `GEMINI.md` 都是指向本文件 `AGENTS.md` 的 symlink
- 發現 bug 時，請先參考 `docs/pitfalls.md` 以避免重複踩雷
