# vgm

在 Apple Silicon Mac 上用 Wine + Game Porting Toolkit (D3DMetal) 跑 Windows 版 Steam 的輕量啟動器。
使用者只玩單機遊戲,要求:快、輕量、簡單易懂、容易擴充。請用繁體中文回覆。

## 結構

- `vgm` — 全部邏輯,單一 bash 腳本。必須相容 macOS 內建的 bash 3.2(不用關聯陣列、`${x,,}`、`mapfile`)。
- `backends/<名稱>.sh` — 圖形後端,定義 `backend_env`(必要)與 `backend_install`(選用)。
- `profiles/<appid>.conf` — 單一遊戲設定檔;`default.conf` 為共用預設。`~/.config/vgm/` 下的同名檔優先。
- `tests/run.sh` — 用假的 Wine 驗證參數與環境變數,改完 `vgm` 一定要跑。

資料位置:Wine 環境在 `~/.vgm/prefix`,啟動紀錄在 `~/.vgm/logs/last.log`。
Wine 是 9.0(Sikarugir 的 `WS12WineCX24.0.7_7`),由 `vgm setup` 下載到 `~/.vgm/wine/cx24`。
Homebrew cask `gcenx/wine/game-porting-toolkit`(`/Applications/Game Porting Toolkit.app`)只用來提供 D3DMetal 與共用函式庫。

## Wine 版本的限制(2026-11-10 在 M5 Air / macOS 27 實測)

- cask 版本 3.0 指的是 D3DMetal;它內附的 Wine 是 7.7,**不能用**:64 位元 Steam 呼叫
  `BCryptGenRandom(BCRYPT_RNG_ALG_HANDLE)`,Wine 8.0 以前的 bcrypt.dll 會把 0x81 當指標讀而當機。
- D3DMetal 的橋接 DLL 匯入 `ntdll.__wine_unix_call`,Wine 9.10 以後移除 → Wine 10/11 掛不上 D3DMetal。
- 所以只能用 Wine 8.0–9.0。換 Wine 版本前先用 `objdump -p ntdll.dll | grep __wine_unix_call` 確認。
- 這份 Wine 不自帶 dylib,`need_wine` 用 `DYLD_FALLBACK_LIBRARY_PATH` 借用 GPTK 的;
  macOS 會清掉經過 `/bin/bash` 傳入的 `DYLD_*`,所以只能在腳本內設定。
- D3DMetal 透過 `WINEDLLPATH_PREPEND` 掛上(見 `backends/d3dmetal.sh`),連結目錄在 `~/.vgm/d3dmetal`。
- 已驗證:steam.exe 與 steamwebhelper 行程可持續存活、D3DMetal 的 d3d11/dxgi 可載入並初始化。
- **未解決:使用者回報 Steam 仍然「開不起來」**(行程活著但無法正常使用,原因未查);沒有任何遊戲實際跑過。
- **專案已於 2026-11-10 由使用者決定作廢**,本機安裝的東西已用 `vgm uninstall` 移除。
- Steam 自我更新時原行程以代碼 42 結束,屬正常;`launch` 已特別處理。
- 跑 `tests/run.sh` 前先 `vgm kill`,否則「Steam 沒在跑時不重啟」那一項會因為真的 Steam 而失敗。
  測試裡的 uninstall 一律用複製到暫存目錄的腳本執行,不要改回直接跑專案的 `vgm`(會刪到真機的捷徑)。

## 原則

- 保持精簡:不加常駐程式、GUI、額外相依套件。新功能優先做成 backend 或 profile。
- 註解、訊息、README 用繁體中文。
- 在 `claude/admiring-clarke-kcqlz5` 分支開發,不要自行開 PR。
