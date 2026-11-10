# vgm

在 Apple Silicon Mac 上用 Wine + Game Porting Toolkit (D3DMetal) 跑 Windows 版 Steam 的輕量啟動器。
使用者只玩單機遊戲,要求:快、輕量、簡單易懂、容易擴充。請用繁體中文回覆。

## 結構

- `vgm` — 全部邏輯,單一 bash 腳本。必須相容 macOS 內建的 bash 3.2(不用關聯陣列、`${x,,}`、`mapfile`)。
- `backends/<名稱>.sh` — 圖形後端,定義 `backend_env`(必要)與 `backend_install`(選用)。
- `profiles/<appid>.conf` — 單一遊戲設定檔;`default.conf` 為共用預設。`~/.config/vgm/` 下的同名檔優先。
- `tests/run.sh` — 用假的 Wine 驗證參數與環境變數,改完 `vgm` 一定要跑。

資料位置:Wine 環境在 `~/.vgm/prefix`,啟動紀錄在 `~/.vgm/logs/last.log`。
Wine 來自 Homebrew cask `gcenx/wine/game-porting-toolkit`,安裝在 `/Applications/Game Porting Toolkit.app`。

## 原則

- 保持精簡:不加常駐程式、GUI、額外相依套件。新功能優先做成 backend 或 profile。
- 註解、訊息、README 用繁體中文。
- 在 `claude/admiring-clarke-kcqlz5` 分支開發,不要自行開 PR。

## 目前待解的問題(解決後請刪除這一節)

狀態(2026-11-10,M5 MacBook Air):`./vgm setup` 成功,Game Porting Toolkit 3.0-3 與 Windows 版 Steam 都已安裝。

症狀:第一次 `vgm steam` 出現 Steam 的更新視窗,更新完成後主視窗/登入視窗沒有出現。
之後再執行 `vgm steam` 會立刻結束且沒有任何輸出(結束代碼 0)。

尚未驗證的推測:

1. `steamwebhelper`(Steam 介面用的 Chromium 元件)在這版 Wine 起不來,所以沒有視窗。
2. 之後的 `vgm steam` 立刻結束,是因為背景還有卡住的 Steam,新行程把訊息轉過去就退出了。

這份腳本先前只在 Linux 上用假的 Wine 測過,這是第一次在真機上跑,`vgm` 本身有 bug 也有可能。

建議的診斷步驟:

1. `./vgm log` 看有哪些 Windows 行程還在、上次的紀錄寫了什麼。
2. `./vgm kill`,再 `VGM_DEBUG=1 ./vgm steam` 重現,從 `~/.vgm/logs/last.log` 找 steamwebhelper 的錯誤。
   也看 `~/.vgm/prefix/drive_c/Program Files (x86)/Steam/logs/` 下 Steam 自己的紀錄。
3. 逐一嘗試啟動參數,例如 `./vgm steam -cef-disable-gpu`(參數會直接傳給 steam.exe)。
4. 找到可行的做法後,寫進 `profiles/default.conf` 的 `STEAM_ARGS` 或 `vgm` 本身,更新 README 的疑難排解,
   並移除 README 開頭「尚未在真正的 Mac 上跑過」的警語。
