# D3DMetal(Apple Game Porting Toolkit):DirectX 11/12 → Metal。預設後端,相容性與效能最好。
#
# D3DMetal 的檔案在 Game Porting Toolkit 裡,和它那份 Wine 7.7 的 DLL 混在同一個目錄。
# 這裡建一個「只含 D3DMetal」的連結目錄,再用 WINEDLLPATH_PREPEND 讓 Wine 優先從這裡載入
# d3d11/d3d12/dxgi 等 DLL。全部是符號連結,不複製檔案;Game Porting Toolkit 更新後會自動跟上。
backend_env() {
  local dir="$VGM_HOME/d3dmetal" ext="$GPTK/lib/external" so name
  if [ ! -e "$ext/libd3dshared.dylib" ]; then
    warn "找不到 D3DMetal($ext),遊戲將使用 Wine 內建的轉譯(較慢)。請執行:$ME setup"
    return 0
  fi
  if [ ! -e "$dir/wine/x86_64-windows/d3d11.dll" ]; then
    rm -rf "$dir"
    mkdir -p "$dir/external" "$dir/wine/x86_64-windows" "$dir/wine/x86_64-unix"
    ln -s "$ext/libd3dshared.dylib" "$ext/D3DMetal.framework" "$dir/external/"
    # GPTK 裡凡是「連到 libd3dshared.dylib 的 .so」就是 D3DMetal 的元件
    for so in "$GPTK"/lib/wine/x86_64-unix/*.so; do
      [ -L "$so" ] || continue
      name="$(basename "$so" .so)"
      ln -s ../../external/libd3dshared.dylib "$dir/wine/x86_64-unix/$name.so"
      ln -s "$GPTK/lib/wine/x86_64-windows/$name.dll" "$dir/wine/x86_64-windows/$name.dll"
    done
  fi
  export WINEDLLPATH_PREPEND="$dir/wine"
  export CX_APPLEGPTK_LIBD3DSHARED_PATH="$dir/external/libd3dshared.dylib"
  export D3DM_ENABLE_METALFX="${D3DM_ENABLE_METALFX:-1}" # 遊戲內的 DLSS 選項改由 MetalFX 升頻
}
