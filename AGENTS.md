# 專案開發指南 (AGENTS.md)

## Commit 規範

- 所有 commit 必須符合 Conventional Commits 格式（例如：`feat: ...`、`fix: ...`、`docs: ...`、`test: ...`）
- commit message 必須包含 body，且以 bullet points 描述本次變更內容

## 注意事項

- `CLAUDE.md` 和 `GEMINI.md` 都是指向本文件 `AGENTS.md` 的 symlink
- 發現 bug 時，請先參考 `docs/pitfalls.md` 以避免重複踩雷
- 需要整理格式時，請在 repo 根目錄執行 `swiftformat .`（Swift 版本為 5.0）
