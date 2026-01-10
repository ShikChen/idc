# Implementation Plan

## Phase 1: idc-server iOS App 基礎

- [x] 設定 iOS 16+ deployment target，確認 Simulator/真機可啟動
- [x] 透過 Swift Package Manager 加入 FlyingFox，確保專案可編譯
- [x] 建立最小 host app（可空白 UI）
- [x] 在 UI Test target 建立 HTTP server 管理層（start/stop、port 設定、錯誤直接拋出）
- [x] 在 UI Test target 實作 `GET /health` 端點與回應模型
- [ ] 在 UI Test target 實作 `GET /info` 端點（先回傳基本裝置資訊）
- [x] 以 UI Test 啟動 server（xcodebuild test / Xcode Test Runner）

## Phase 2: idc-server XCUITest 整合

- [ ] 建立 XCUITest target
- [ ] `GET /screenshot` 截圖端點
- [ ] `GET /hierarchy` UI 元素樹端點
- [ ] `POST /tap` 點擊端點
- [ ] `POST /swipe` 滑動端點
- [ ] `POST /input` 輸入文字端點
- [ ] 研究 XCUITest 如何與 HTTP server 協作

## Phase 3: idc-cli 基礎

- [ ] 建立 Swift Package 專案 (`idc-cli/`)
- [ ] 實作 ArgumentParser CLI 框架
- [ ] `idc devices list` (simctl wrapper)
- [ ] `idc devices info`
- [ ] `idc devices boot`
- [ ] `idc devices shutdown`
- [ ] `idc server deploy` 自動部署 idc-server 到 Simulator
- [ ] JSON 輸出格式支援 (`--json`)

## Phase 4: idc-cli + idc-server 整合

- [ ] HTTP client 整合
- [ ] `idc ui screenshot`
- [ ] `idc ui tap`
- [ ] `idc ui swipe`
- [ ] `idc ui input`
- [ ] `idc ui hierarchy`
- [ ] 服務發現（Bonjour/mDNS 或 localhost:port）
- [ ] Simulator 和 Real Device 統一介面
- [ ] 自動選擇設備（只有一台時不需 `--udid`）

## Phase 5: Agent Skill 打包

- [ ] 撰寫 SKILL.md
- [ ] 撰寫 references/COMMANDS.md
- [ ] 測試與 Claude Code 整合
- [ ] 錯誤處理與 edge cases
