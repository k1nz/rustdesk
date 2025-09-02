# build_with_bridge.ps1

Write-Host "正在安装 flutter_rust_bridge_codegen..." -ForegroundColor Green
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked

Write-Host "正在生成 bridge 文件..." -ForegroundColor Green
$bridge_tool = "$env:USERPROFILE\.cargo\bin\flutter_rust_bridge_codegen.exe"

if (Test-Path $bridge_tool) {
    Write-Host "找到 flutter_rust_bridge_codegen: $bridge_tool" -ForegroundColor Green
    
    # 生成 bridge 文件
    & $bridge_tool `
        --rust-input .\src\flutter_ffi.rs `
        --dart-output .\flutter\lib\generated_bridge.dart `
        --c-output .\flutter\macos\Runner\bridge_generated.h
    
    # 复制头文件
    if (Test-Path ".\flutter\macos\Runner\bridge_generated.h") {
        Copy-Item ".\flutter\macos\Runner\bridge_generated.h" ".\flutter\ios\Runner\bridge_generated.h"
        Write-Host "Bridge 文件生成成功！" -ForegroundColor Green
    } else {
        Write-Host "错误：无法生成 bridge 文件" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "错误：找不到 flutter_rust_bridge_codegen" -ForegroundColor Red
    Write-Host "请检查安装是否成功" -ForegroundColor Red
    exit 1
}

Write-Host "正在设置环境变量..." -ForegroundColor Green
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"

Write-Host "开始构建..." -ForegroundColor Green
python3 .\build.py --portable --hwcodec --flutter --vram --skip-portable-pack