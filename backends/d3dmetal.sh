# D3DMetal(Apple Game Porting Toolkit):DirectX 11/12 → Metal。預設後端,相容性與效能最好。
# 它已內建在 Game Porting Toolkit 的 Wine 裡,不需要安裝也不需要 DLL 覆寫。
backend_env() {
  export D3DM_ENABLE_METALFX="${D3DM_ENABLE_METALFX:-1}" # 遊戲內的 DLSS 選項改由 MetalFX 升頻
}
