# Server side Refactor TODO (idc-serverUITests)

## API / Handler
- [x] 抽出共用的 request decode + error mapping（含 DecodingError -> 400），避免 /tap、/find 重複邏輯
- [x] 統一錯誤回應格式（例如加上 errorCode），讓 client 更容易處理
- [x] 把 route 註冊集中成表格或 enum，減少手動 appendRoute 的重複樣板

## Concurrency / Lifecycle
- [x] 重整 TestServer lifecycle：統一 start / runForever，支援 cancel/await，避免 stop race
- [x] 明確定義 MainActor 範圍，只在必要時接觸 XCUI* API，其餘資料整理移出主執行緒
- [x] TapService/FindService 的 retry/limit/timeout 改成可配置常數

## Domain / Models
- [ ] 合併 TapElement / FindElement / SnapshotNode 的共通欄位成 Shared model
- [ ] 將 Frame / JSONValue / elementType mapping 移到 Models/Common
- [ ] PlanExecutor 分離「驗證」與「查詢」，提高可測試性

## Running App
- [ ] 強化前景 app 判斷：排除 unknownBundleId、必要時重試
- [ ] 允許指定 bundleId（可選），避免多 app 前景判定不穩

## Tests
- [ ] 新增 /stop、/screenshot endpoint 測試
- [x] 新增 invalid JSON body / empty body 的錯誤碼測試
- [ ] 新增 tap point 超出範圍 / 非有限值 / limit 上限的測試

## 檔案結構調整
- [x] 將 `TestServer.swift` 移到 `Server/`
- [x] 建立 `Models/`（攤平）
- [x] ObjC bridge 放到 `Infrastructure/ObjC/`（AXClientProxy、XCTestDaemonsProxy 等）
- [x] 測試 helper 抽到 `Tests/TestHelpers.swift`（共用 plan builder、waitForForegroundFixture 等）
