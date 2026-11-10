# DXVK:DirectX 9/10/11 → Vulkan → MoltenVK → Metal。實驗性,給 D3DMetal 跑不好的舊遊戲試。
# 請使用 macOS 專用版本:https://github.com/Gcenx/DXVK-macOS/releases
#   vgm backend install dxvk <解壓後的目錄>
# 注意:DXVK 需要 libMoltenVK.dylib,Game Porting Toolkit 沒有附;請另外取得後放進 $GPTK/lib 才能用。
backend_env() {
  dll_override "dxgi,d3d9,d3d10core,d3d11=n,b"
  export DXVK_ASYNC="${DXVK_ASYNC:-1}" # 非同步編譯著色器,減少卡頓
}

backend_install() {
  [ -n "$1" ] || die "用法:vgm backend install dxvk <DXVK 目錄>"
  install_dlls "$1"
}
