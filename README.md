# vgm — 在 Apple Silicon Mac 上玩 Steam Windows 遊戲

一支約 400 行的 shell 腳本,把 Windows 版 Steam 跑在 M 系列 Mac(M5 Air 等)上。

```
Windows 遊戲 (x86-64)
   │  Rosetta 2      CPU 指令轉譯(Apple 內建,預先編譯,接近原生速度)
   │  Wine           Windows API → macOS API(不是虛擬機,不用裝 Windows)
   │  D3DMetal       DirectX 11/12 → Metal(Apple Game Porting Toolkit)
   ▼
Apple GPU
```

**為什麼這樣最快最輕量:** 這是目前 Mac 上跑 Windows 遊戲效能最高的路線,比虛擬機 (Parallels/UTM) 快,
因為沒有模擬整台電腦。`vgm` 本身不做任何轉譯,只負責安裝、設定環境變數、啟動,然後就把自己換成 Wine
行程 (`exec`) —— 沒有常駐程式、沒有 GUI、沒有相依套件,只用 macOS 內建的 bash。

> ⚠️ **此專案已停止開發(2026-11-10)。** 在 M5 MacBook Air(macOS 27)上實測的最終狀態:
> Steam 的行程在 Wine 9.0 上可以持續執行、D3DMetal 的 DLL 可以載入,但使用者端仍然無法正常開啟使用,
> 沒有任何遊戲實際跑起來過。過程中查到的根因與版本限制記在下面「為什麼要兩個 Wine」,留給之後想走這條路的人參考。

## 快速開始

需要:Apple Silicon Mac、macOS 15 以上(建議 macOS 26)、[Homebrew](https://brew.sh)。

```bash
git clone https://github.com/jojoyouth/videogameonmac.git
```

```bash
cd videogameonmac && ./vgm setup
```

```bash
./vgm steam
```

`setup` 會依序安裝 Rosetta 2、Game Porting Toolkit(提供 D3DMetal,來自
[Gcenx 的 Homebrew cask](https://github.com/Gcenx/game-porting-toolkit))、Wine 9.0(下載到 `~/.vgm/wine`)、
建立虛擬 C: 槽,並安裝 Windows 版 Steam。每一步都會先檢查,重複執行不會重裝。
第一次開 Steam 會先自我更新,要等幾分鐘才會出現登入視窗。

### 為什麼要兩個 Wine

Game Porting Toolkit 的 cask 版本寫 3.0,但那是 **D3DMetal** 的版本,裡面附的 Wine 本體是 2022 年的 7.7。
2026 年的 64 位元 Steam 會用到 Wine 7.7 沒有的加密 API(`BCRYPT_RNG_ALG_HANDLE`),一啟動就當機。
反過來,太新的 Wine(9.10 以後)又拿掉了 D3DMetal 需要的 `__wine_unix_call` 介面,D3DMetal 掛不上去。

| Wine 版本 | 新版 Steam | D3DMetal |
| --- | --- | --- |
| 7.7(Game Porting Toolkit 內建) | 當機 | 可以 |
| **9.0(vgm 使用)** | 可以 | 可以 |
| 10、11 | 可以 | 載不進去 |

所以 `vgm` 用的是 Wine 9.0([Sikarugir 以 CrossOver 開放原始碼編譯的免費版本](https://github.com/Sikarugir-App/Engines)),
Game Porting Toolkit 只拿來提供 D3DMetal 和幾個共用函式庫。

登入 Steam 後照平常的方式下載、按「開始遊戲」即可。

想在任何目錄直接打 `vgm`(不用 `./`),建一個捷徑:

```bash
ln -s "$PWD/vgm" "$(brew --prefix)/bin/vgm"
```

**已經有 Mac 版 Steam?** 兩個都留著。Mac 版只能下載有 macOS 版本的遊戲;只有 Windows 版的遊戲
要從這裡的 Windows 版 Steam 下載。同一個帳號、同一個遊戲庫,有 Mac 原生版的遊戲用 Mac 版 Steam 玩會更快。

## 指令

| 指令 | 作用 |
| --- | --- |
| `vgm setup` | 一鍵安裝所有東西 |
| `vgm steam` | 開啟 Steam |
| `vgm list` | 列出已安裝的遊戲與 appid |
| `vgm play <appid>` | 直接啟動遊戲,並套用該遊戲的設定檔 |
| `vgm run [-p 設定檔] <exe>` | 不經 Steam 執行 exe(GOG 遊戲、安裝程式) |
| `vgm backend list` / `install` | 管理圖形後端 |
| `vgm doctor` | 檢查環境哪裡有問題 |
| `vgm log` | 顯示執行中的 Windows 程式與上次啟動的紀錄 |
| `vgm kill` | 關閉所有 Windows 程式 |
| `vgm wine <參數>` | 直接呼叫 Wine,例如 `vgm wine winecfg` |
| `vgm uninstall` | 移除 vgm 安裝的所有東西(`-n` 只列出、`-y` 不逐項詢問) |

## 針對單一遊戲調整(設定檔)

設定檔是一般的 shell 檔,放在 `profiles/<appid>.conf`(或 `~/.config/vgm/profiles/`,後者優先)。
只要寫出和 `profiles/default.conf` 不同的地方:

```bash
# profiles/1245620.conf
HUD=1                        # 顯示 FPS
GAME_ARGS="-windowed"        # 遊戲啟動參數
export D3DM_SUPPORT_DXR=1    # 任何環境變數都可以直接 export
```

之後 `vgm play 1245620` 會自動套用。遊戲會繼承 Steam 啟動當下的環境變數,所以切換到不同設定檔時
`vgm` 會自動重啟 Steam;從 Steam 視窗裡直接按「開始遊戲」則是沿用目前的設定檔。

## 擴充:新增圖形後端

後端就是 `backends/<名稱>.sh` 裡的一兩個函式。例如想加一個新的轉譯層:

```bash
# backends/mylayer.sh
backend_env() {                       # 必要:啟動前設定環境變數
  dll_override "d3d11,dxgi=n,b"       # 改用自己放進去的 DLL
}
backend_install() {                   # 選用:vgm backend install mylayer <目錄>
  install_dlls "$1"                   # 把 DLL 複製進虛擬 C: 槽
}
```

然後在設定檔寫 `BACKEND=mylayer`。內建兩個後端:

- **d3dmetal**(預設)—— DirectX 11/12,相容性與效能最好。
- **dxvk**(實驗性)—— DirectX 9/10/11 走 Vulkan/MoltenVK,給 D3DMetal 跑不好的舊遊戲。
  需自行下載 [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS/releases) 後執行 `vgm backend install dxvk <目錄>`。

要換 Wine 版本(例如自己編譯的),設 `VGM_WINE=/path/to/wine` 即可;版本限制見上面「為什麼要兩個 Wine」。

## 哪些能玩、哪些不能

這條路線**做不到「Windows 能玩的全部都能玩」**,沒有任何方案做得到。實際情況:

- ✅ 大多數 DirectX 11/12 單機與連線遊戲(艾爾登法環、電馭叛客 2077、柏德之門 3 等級的大作都跑得動)。
- ✅ 需要 AVX/AVX2 的遊戲(macOS 15 起 Rosetta 支援)。
- ❌ **核心層級反作弊**的遊戲:Valorant、Fortnite、Apex Legends、PUBG、Call of Duty 多人模式、
  多數 EA 新作等。它們會檢查 Windows 核心,Wine 沒有核心可以給它檢查,這無法繞過。
  這類遊戲在 Mac 上只能用 GeForce NOW 之類的雲端串流。
- ⚠️ 部分 DirectX 9 以前的老遊戲、需要特殊啟動器的遊戲,可能要換後端或個別調整。

買之前可以先查 [AppleGamingWiki](https://www.applegamingwiki.com) 或
[ProtonDB](https://www.protondb.com)(Linux 上能跑的,這裡多半也能跑)。

## MacBook Air 效能建議

Air 沒有風扇,長時間高負載會過熱降頻,所以重點是**降低 GPU 負擔**:

- 遊戲解析度設 1440×900 或 1680×1050,不要用原生 Retina 解析度。
- 遊戲裡有 DLSS / FSR 就開:`vgm` 預設把 DLSS 轉成 Apple 的 MetalFX 升頻。
- 鎖 30 或 60 FPS 比不鎖幀更穩,也比較不燙。
- 用**全螢幕**玩,macOS 會自動進入遊戲模式(提高遊戲的 CPU/GPU 優先權)。
- 光線追蹤預設關閉,建議維持。
- 接電源、墊高機身散熱。用 `HUD=1` 看實際 FPS 再調整。

## 疑難排解

- **先跑 `vgm doctor`**,它會告訴你缺什麼。
- **看紀錄:** `vgm kill` 後用 `VGM_DEBUG=1 vgm steam` 重跑,再執行 `vgm log`。
- **打了 `vgm steam` 沒反應或立刻結束:** 先 `vgm kill` 再開。還是一樣就看紀錄裡有沒有
  `Unhandled page fault`;若 `vgm doctor` 顯示的 Wine 不在 `~/.vgm/wine` 底下,代表用到了不相容的 Wine。
  Steam 自己的紀錄在 `~/.vgm/prefix/drive_c/Program Files (x86)/Steam/logs/`,`bootstrap_log.txt` 最有用。
- **Steam 視窗全黑或空白:** 在 `~/.config/vgm/profiles/default.conf` 寫入 `STEAM_ARGS="-cef-disable-gpu"`。
  (正常情況下 Steam 會自己偵測並關閉介面的 GPU 加速,不需要這個參數。)
- **遊戲一開就閃退:** 多半是反作弊(見上)或缺少執行階段元件;從紀錄檔找線索,或換 `BACKEND=dxvk` 試試。
- **整個重來:** `vgm kill && rm -rf ~/.vgm`,再跑一次 `vgm setup`(遊戲需重新下載)。

## 完整移除

```bash
./vgm uninstall -n
```

先用 `-n` 看會移除哪些東西,確認後再執行 `./vgm uninstall`(逐項詢問,預設不刪)。它只處理 vgm 自己建立的東西:

- `~/.vgm`(Windows 環境、遊戲、存檔、Wine)與 `~/.config/vgm`(自訂設定)
- PATH 上指向這支腳本的 `vgm` 捷徑
- Homebrew 的 `game-porting-toolkit` cask 與 `gcenx/wine` tap

不會動 Rosetta 2、Homebrew 本身、Mac 版 Steam 或其他任何檔案;要刪除的目錄必須在家目錄底下且名稱含 `vgm`,否則拒絕。
專案目錄本身不會自動刪,最後會印出指令讓你自己執行。

## 開發

```bash
tests/run.sh
```

測試用假的 Wine 驗證參數與環境變數是否正確,不需要 Mac。Steam 正在執行時有一項「不重啟」的測試會失敗,先 `vgm kill` 再跑。

| 路徑 | 內容 |
| --- | --- |
| `vgm` | 全部邏輯 |
| `backends/` | 圖形後端,一個檔案一個 |
| `profiles/` | 預設與範例設定檔 |
| `tests/run.sh` | 測試 |
