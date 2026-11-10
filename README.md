# vgm — 在 Apple Silicon Mac 上玩 Steam Windows 遊戲

一支約 250 行的 shell 腳本,把 Windows 版 Steam 跑在 M 系列 Mac(M5 Air 等)上。

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

> ⚠️ 這個專案是在 Linux 上用假的 Wine 測試邏輯,**尚未在真正的 Mac 上跑過**。
> 第一次使用若遇到問題,請看最下面的「疑難排解」。

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

`setup` 會依序安裝 Rosetta 2、Game Porting Toolkit(Wine + D3DMetal,來自
[Gcenx 的 Homebrew cask](https://github.com/Gcenx/game-porting-toolkit))、建立虛擬 C: 槽,
並安裝 Windows 版 Steam。每一步都會先檢查,重複執行不會重裝。

登入 Steam 後照平常的方式下載、按「開始遊戲」即可。

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
| `vgm kill` | 關閉所有 Windows 程式 |
| `vgm wine <參數>` | 直接呼叫 Wine,例如 `vgm wine winecfg` |

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

要換 Wine 版本(例如 CrossOver 或自己編譯的),設 `VGM_WINE=/path/to/wine` 即可。

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
- **看紀錄:** `VGM_DEBUG=1 vgm steam`,輸出會寫到 `~/.vgm/logs/last.log`。
- **Steam 視窗全黑或空白:** 在 `~/.config/vgm/profiles/default.conf` 寫入 `STEAM_ARGS="-cef-disable-gpu"`。
- **遊戲一開就閃退:** 多半是反作弊(見上)或缺少執行階段元件;從紀錄檔找線索,或換 `BACKEND=dxvk` 試試。
- **整個重來:** `vgm kill && rm -rf ~/.vgm`,再跑一次 `vgm setup`(遊戲需重新下載)。

## 開發

```bash
tests/run.sh
```

測試用假的 Wine 驗證參數與環境變數是否正確,不需要 Mac。

| 路徑 | 內容 |
| --- | --- |
| `vgm` | 全部邏輯 |
| `backends/` | 圖形後端,一個檔案一個 |
| `profiles/` | 預設與範例設定檔 |
| `tests/run.sh` | 測試 |
