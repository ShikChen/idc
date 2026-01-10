# idc - iOS Device Control

iOS 自動化工具組，讓 AI coding agent 可以控制 iOS 模擬器和真實設備。

## 系統架構

**macOS Host**

- **idc-cli (Agent Skill)** - 命令列工具，提供 `idc devices list`, `idc ui tap`, `idc ui screenshot` 等命令
  - **simctl** - 輔助功能：boot/shutdown、install/launch companion app
  - **HTTP Client** - 連接到 idc-server 執行 UI 自動化

**iOS Simulator / Real Device**

- **idc-server (Companion App)**
  - HTTP Server
  - XCUITest Runner
  - 提供 /tap, /swipe, /input, /describe-ui, /screenshot 等 API

## 兩個專案

| 專案           | 平台      | 說明                                               |
| -------------- | --------- | -------------------------------------------------- |
| **idc-server** | iOS App   | Companion app，在設備上運行 HTTP server + XCUITest |
| **idc-cli**    | macOS CLI | 統一介面，執行檔名稱為 `idc`                       |

### 為什麼需要 Companion App？

`simctl` 無法取得 UI/AX tree：

- `simctl` 只能做：boot, shutdown, install, launch, screenshot, openurl 等
- `simctl ui` 只控制外觀設定（dark mode），不能查詢 UI 元素
- macOS AXUIElement 只能存取 Simulator.app 的 macOS UI，無法存取模擬器內的 iOS app UI

因此 Simulator 和 Real Device 都需要 idc-server companion app 來做 UI 自動化（透過 XCUITest）。

---

## idc-server（iOS Companion App）

### 技術架構

```
idc-server iOS App
├── HTTP Server (運行在設備上)
│   ├── GET  /health              # 健康檢查
│   ├── GET  /info                # 設備資訊
│   ├── GET  /screenshot          # 截圖
│   ├── GET  /describe-ui         # UI 元素樹
│   ├── POST /tap                 # 點擊
│   ├── POST /swipe               # 滑動
│   ├── POST /input               # 輸入文字
│   └── POST /button              # 硬體按鈕
│
├── UI Automation Engine
│   └── XCUITest Integration      # 完整 UI 控制
│
└── Screen Capture
    └── Screenshot (ReplayKit/IOSurface)
```

### 實作方式：XCUITest Runner

- 使用 XCTest framework 提供完整 UI 自動化
- 類似 WebDriverAgent 的架構
- 優點：功能完整、可靠、官方支援
- 需要作為 test target 運行

### HTTP API

```
GET  /health                      → { "status": "ok" }
GET  /info                        → { "name": "iPhone", "os": "18.2", ... }
GET  /screenshot?format=png       → image/png binary
GET  /describe-ui                 → { "root": { ... } }
POST /tap      { "x": 200, "y": 400 }
POST /swipe    { "fromX": 200, "fromY": 600, "toX": 200, "toY": 200 }
POST /input    { "text": "Hello" }
POST /button   { "button": "home" }
POST /element/find   { "query": { "label": "Submit" } }
POST /element/{id}/tap
```

---

## idc-cli（macOS CLI + Agent Skill）

### CLI 命令

```bash
# 設備管理
idc devices list [--json]
idc devices boot [--udid <udid>]
idc devices shutdown [--udid <udid>]

# 伺服器管理
idc server deploy [--udid <udid>]
idc server status [--udid <udid>]

# App 管理
idc app install <path> [--udid <udid>]
idc app launch <bundle-id> [--udid <udid>]
idc app terminate <bundle-id> [--udid <udid>]

# UI 自動化（需要 idc-server 運行）
idc ui screenshot [-o file] [--udid <udid>]
idc ui tap <x> <y> [--udid <udid>]
idc ui swipe <x1> <y1> <x2> <y2> [--udid <udid>]
idc ui input <text> [--udid <udid>]
idc describe-ui [--json] [--udid <udid>]

# 系統功能
idc system openurl <url> [--udid <udid>]
idc system location <lat> <lon> [--udid <udid>]
```

### 設備選擇策略

- 如果只有一台設備，自動使用（不需指定 `--udid`）
- 如果有多台設備，提示選擇或用 `--udid` 指定

---

## 技術選型

| 組件            | 技術                   |
| --------------- | ---------------------- |
| idc-cli         | swift-argument-parser  |
| idc-server HTTP | GCDWebServer / Embassy |
| UI 自動化       | XCUITest               |
| 服務發現        | Bonjour (mDNS)         |

## 參考資料

- [Agent Skills Specification](https://agentskills.io/specification)
- [WebDriverAgent](https://github.com/appium/WebDriverAgent)
- [swift-argument-parser](https://github.com/apple/swift-argument-parser)
