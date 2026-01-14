# Implementation Plan

## Phase 1: idc-server（XCUITest runner）

- [x] 建立最小 host app（可空白 UI）
- [x] 透過 Swift Package Manager 加入 FlyingFox
- [x] 在 UI Test target 建立 HTTP server 管理層
- [x] 實作 `GET /health` 端點
- [x] 實作 `GET /info` 端點（name/model/os_version/is_simulator）
- [x] 提供 keep-alive 測試入口（手動啟動 server）

## Phase 2: idc-cli 基礎 + 自動啟動 server（Simulator）

- [x] 建立 `idc-cli/` Swift Package（executable）
- [x] 加入 swift-argument-parser，建立 `idc` root command
- [ ] 建立共用設定（server port、xcodebuild 路徑、cache 路徑）
- [x] 實作 simulator 裝置偵測（已 boot；多台要求 `--udid`）
- [x] `idc server start`：呼叫 xcodebuild 以 UI Test 啟動 server（keep-alive test）
- [x] `idc server health`：檢查 `/health`
- [ ] `idc server health`：若沒起來則自動啟動
- [ ] 啟動後輪詢 `/health` 直到可用或超時
- [x] 清楚的錯誤訊息（找不到 booted simulator / 多台未指定 / xcodebuild 失敗）

## Phase 3: idc-server XCUITest 擴充

- [x] `GET /screenshot` 截圖端點
- [ ] `GET /describe-ui` UI 元素樹端點
- [ ] `GET /describe-ui` 支援 ref 產出（snapshotId + ref map）
- [ ] `POST /tap` 點擊端點
- [ ] `POST /swipe` 滑動端點
- [ ] `POST /input` 輸入文字端點
- [ ] /info 支援 `IDC_UDID`（由 CLI 傳入）
- [ ] 研究 XCUITest 如何與 HTTP server 協作

## Phase 4: idc-cli 功能擴充

- [ ] `idc devices list` (simctl wrapper)
- [ ] `idc devices info`
- [ ] `idc devices boot`
- [ ] `idc devices shutdown`
- [ ] `idc server deploy` 自動部署 idc-server 到 Simulator
- [ ] JSON 輸出格式支援 (`--json`)

## Phase 5: idc-cli + idc-server 整合

- [ ] HTTP client 整合
- [x] `idc screenshot`
- [ ] `idc ui tap`
- [ ] `idc ui swipe`
- [ ] `idc ui input`
- [ ] `idc describe-ui`
- [ ] `idc describe-ui` 顯示/輸出 ref，`idc tap @ref` 支援
- [ ] 服務發現（Bonjour/mDNS 或 localhost:port）
- [ ] Simulator 和 Real Device 統一介面
- [ ] 自動選擇設備（只有一台時不需 `--udid`）

## Phase 6: 真機支援

- [ ] 加入真機目的地支援（`--udid`）
- [ ] 簽名/授權策略（必要時 `-allowProvisioningUpdates`）
- [ ] 真機專用錯誤訊息與指引

## Phase 7: Agent Skill 打包

- [ ] 撰寫 SKILL.md
- [ ] 撰寫 references/COMMANDS.md
- [ ] 測試與 Claude Code 整合
- [ ] 錯誤處理與 edge cases
