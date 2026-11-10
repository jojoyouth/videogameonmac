#!/bin/bash
# 用假的 Wine 測試 vgm 的邏輯(不需要 Mac)。用法:tests/run.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" VGM_HOME="$T/vgm" VGM_CONFIG="$T/config" VGM_WINE="$T/bin/wine" VGM_GPTK="$T/gptk"
unset WINEPREFIX WINEDLLOVERRIDES MTL_HUD_ENABLED
STEAM_DIR="$VGM_HOME/prefix/drive_c/Program Files (x86)/Steam"
mkdir -p "$HOME" "$T/bin" "$STEAM_DIR/steamapps" "$VGM_CONFIG/profiles" "$VGM_HOME/prefix/drive_c/windows/system32"
touch "$STEAM_DIR/steam.exe"

# 假的 Game Porting Toolkit:一個 D3DMetal 元件 (d3d11) 加一個不相干的 Wine DLL (kernel32)
mkdir -p "$VGM_GPTK/lib/external/D3DMetal.framework" "$VGM_GPTK/lib/wine/x86_64-unix" "$VGM_GPTK/lib/wine/x86_64-windows"
touch "$VGM_GPTK/lib/external/libd3dshared.dylib" "$VGM_GPTK/lib/wine/x86_64-unix/kernel32.so"
touch "$VGM_GPTK/lib/wine/x86_64-windows/d3d11.dll" "$VGM_GPTK/lib/wine/x86_64-windows/kernel32.dll"
ln -s ../../external/libd3dshared.dylib "$VGM_GPTK/lib/wine/x86_64-unix/d3d11.so"

# 假 Wine:把收到的參數與環境變數記下來
cat >"$T/bin/wine" <<'W'
#!/bin/bash
{ printf 'ARGS:'; printf ' [%s]' "$@"; echo; env | grep -E '^(WINE|MTL_|D3DM_|DXVK_|ROSETTA_|CX_)' | sort; } >"$VGM_HOME/call"
W
cat >"$T/bin/wineserver" <<'W'
#!/bin/bash
echo "wineserver $*" >>"$VGM_HOME/server"
W
chmod +x "$T/bin/wine" "$T/bin/wineserver"

fail=0
t() { # t <說明> <指令...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok   $name"; else echo "FAIL $name"; fail=1; fi
}
has() { grep -qF -- "$1" "$VGM_HOME/call"; }
hasnt() { ! has "$1"; }
vgm() { "$ROOT/vgm" "$@"; }

vgm steam -silent
t "steam:啟動 steam.exe 並帶上參數" has "Steam/steam.exe] [-silent]"
t "steam:預設關閉除錯輸出" has "WINEDEBUG=-all"
t "steam:開啟 esync/msync 與 AVX" has "ROSETTA_ADVERTISE_AVX=1"
t "steam:d3dmetal 後端開啟 MetalFX" has "D3DM_ENABLE_METALFX=1"
t "steam:預設不顯示 HUD" hasnt "MTL_HUD_ENABLED"
t "d3dmetal:讓 Wine 優先載入 D3DMetal 的 DLL" has "WINEDLLPATH_PREPEND=$VGM_HOME/d3dmetal/wine"
t "d3dmetal:連結 D3DMetal 元件" test -e "$VGM_HOME/d3dmetal/wine/x86_64-windows/d3d11.dll" -a -e "$VGM_HOME/d3dmetal/wine/x86_64-unix/d3d11.so"
t "d3dmetal:不連結 Wine 7.7 自己的 DLL" test ! -e "$VGM_HOME/d3dmetal/wine/x86_64-windows/kernel32.dll"

vgm play 570 -novid
t "play:使用 -applaunch" has "[-applaunch] [570] [-novid]"
t "play:沒有專屬設定檔時沿用 default" grep -qx default "$VGM_HOME/active-profile"

printf 'HUD=1\nBACKEND=dxvk\nGAME_ARGS="-dx11"\n' >"$VGM_CONFIG/profiles/730.conf"
vgm play 730
t "profile:套用遊戲參數" has "[-applaunch] [730] [-dx11]"
t "profile:切換到 dxvk 後端" has "WINEDLLOVERRIDES=dxgi,d3d9,d3d10core,d3d11=n,b"
t "profile:開啟 HUD" has "MTL_HUD_ENABLED=1"
t "profile:Steam 沒在跑時不重啟" test ! -f "$VGM_HOME/server"

(exec -a 'C:\steam.exe' sleep 30) &
fake=$!
sleep 0.3
vgm play 570
t "profile:Steam 執行中切換設定檔會重啟" grep -qx "wineserver -k" "$VGM_HOME/server"
rm -f "$VGM_HOME/server"
vgm play 570
t "profile:設定檔沒變就不重啟" test ! -f "$VGM_HOME/server"
kill $fake 2>/dev/null

echo 'HUD=1' >"$VGM_CONFIG/profiles/default.conf"
vgm run /games/foo.exe -x
t "run:直接執行 exe" has "ARGS: [/games/foo.exe] [-x]"
t "run:使用者的 default.conf 覆蓋內建值" has "MTL_HUD_ENABLED=1"

printf '"AppState"\n{\n\t"appid"\t\t"570"\n\t"name"\t\t"Dota 2"\n}\n' >"$STEAM_DIR/steamapps/appmanifest_570.acf"
t "list:列出 appid 與名稱" bash -c "'$ROOT/vgm' list | grep -qE '^570 +Dota 2$'"

mkdir -p "$T/dxvk/x64" && touch "$T/dxvk/x64/d3d11.dll"
vgm backend install dxvk "$T/dxvk" >/dev/null
t "backend:安裝 DLL 到 system32" test -f "$VGM_HOME/prefix/drive_c/windows/system32/d3d11.dll"
t "backend:list 列出內建後端" bash -c "'$ROOT/vgm' backend list | grep -qx d3dmetal"

echo 'BACKEND=nope' >"$VGM_CONFIG/profiles/1.conf"
t "錯誤:未知後端" bash -c "! '$ROOT/vgm' play 1"
t "錯誤:appid 不是數字" bash -c "! '$ROOT/vgm' play abc"
t "錯誤:未知指令" bash -c "! '$ROOT/vgm' bogus"

# uninstall:只刪 vgm 自己的目錄,其他東西不能動。
# 用假的 brew 避免碰到真的 Homebrew;用複製出來的 vgm 跑,這樣真機 PATH 上指向本專案的捷徑不會被當成目標。
mkdir -p "$T/app" && cp -R "$ROOT/vgm" "$ROOT/backends" "$ROOT/profiles" "$T/app/"
UV="$T/app/vgm"
printf '#!/bin/bash\nexit 1\n' >"$T/bin/brew"; chmod +x "$T/bin/brew"
mkdir -p "$HOME/Documents" && echo keep >"$HOME/Documents/keep.txt"
PATH="$T/bin:$PATH" "$UV" uninstall -n >/dev/null
t "uninstall -n:試跑不刪任何東西" test -d "$VGM_HOME" -a -d "$VGM_CONFIG"
t "uninstall:拒絕名稱不含 vgm 的目錄" bash -c "VGM_HOME='$HOME/Documents' PATH='$T/bin:$PATH' '$UV' uninstall -y >/dev/null 2>&1; test -f '$HOME/Documents/keep.txt'"
t "uninstall:拒絕家目錄本身" bash -c "VGM_HOME='$HOME' PATH='$T/bin:$PATH' '$UV' uninstall -n >/dev/null 2>&1; test -d '$HOME'"
mkdir -p "$HOME/.vgm/prefix" "$HOME/.config/vgm/profiles"
U() { VGM_HOME="$HOME/.vgm" VGM_CONFIG="$HOME/.config/vgm" PATH="$T/bin:$PATH" "$UV" uninstall "$@"; }
echo n | U >/dev/null 2>&1
t "uninstall:回答 n 就不刪" test -d "$HOME/.vgm" -a -d "$HOME/.config/vgm"
U -y >/dev/null 2>&1
t "uninstall -y:刪除資料與設定目錄" test ! -e "$HOME/.vgm" -a ! -e "$HOME/.config/vgm"
t "uninstall -y:不動其他檔案" test -f "$HOME/Documents/keep.txt" -a -d "$HOME/.config"
rm "$STEAM_DIR/steam.exe"
t "錯誤:沒裝 Steam 時提示 setup" bash -c "'$ROOT/vgm' steam 2>&1 | grep -q 'vgm setup'"

exit $fail
