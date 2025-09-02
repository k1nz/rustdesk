# RustDesk Windows Flutter 构建完整指南

## 概述

本指南基于 RustDesk 官方 GitHub Actions 工作流配置，提供从环境准备到成功构建的完整流程。RustDesk 使用 Flutter 作为前端框架，Rust 作为后端核心，通过 Flutter Rust Bridge 实现两者之间的通信。

## 环境要求

### 系统要求
- **操作系统**: Windows 10/11 (64位)
- **架构**: x86_64-pc-windows-msvc
- **内存**: 建议 8GB 以上
- **磁盘空间**: 建议 20GB 以上可用空间

### 必需软件

#### 1. Rust 工具链
```powershell
# 安装 Rust (如果未安装)
# 访问 https://rustup.rs/ 下载安装器

# 验证安装
rustc --version
cargo --version
```

**版本要求**:
- Rust: 1.75 (与官方 CI 保持一致)
- 目标架构: x86_64-pc-windows-msvc

#### 2. Python 3
```powershell
# 安装 Python 3 (如果未安装)
# 访问 https://www.python.org/downloads/

# 验证安装
python --version
python3 --version
```

#### 3. Flutter SDK
```powershell
# 安装 Flutter SDK
# 访问 https://flutter.dev/docs/get-started/install/windows

# 验证安装
flutter --version
flutter doctor
```

**版本要求**:
- Flutter: 3.24.5 (与官方 CI 保持一致)

#### 4. Visual Studio Build Tools
```powershell
# 安装 Visual Studio Build Tools 2022
# 包含以下组件:
# - MSVC v143 - VS 2022 C++ x64/x86 build tools
# - Windows 10/11 SDK
# - CMake tools for Visual Studio
```

#### 5. LLVM 和 Clang
```powershell
# 安装 LLVM (版本 15.0.6)
# 访问 https://releases.llvm.org/download.html
# 或使用包管理器安装
```

#### 6. Git
```powershell
# 安装 Git (如果未安装)
# 访问 https://git-scm.com/download/win

# 验证安装
git --version
```

## 环境变量配置

### 必需环境变量
```powershell
# 设置 VCPKG 默认主机三元组
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"

# 设置 Rust 工具链版本
$env:RUST_VERSION = "1.75"

# 设置 Flutter 版本
$env:FLUTTER_VERSION = "3.24.5"

# 设置 LLVM 版本
$env:LLVM_VERSION = "15.0.6"
```

### 可选环境变量
```powershell
# 设置 Cargo 主目录 (可选)
$env:CARGO_HOME = "$env:USERPROFILE\.cargo"

# 设置 Rustup 主目录 (可选)
$env:RUSTUP_HOME = "$env:USERPROFILE\.rustup"
```

## 项目准备

### 1. 克隆代码库
```powershell
# 克隆 RustDesk 仓库
git clone https://github.com/rustdesk/rustdesk.git
cd rustdesk

# 初始化子模块
git submodule update --init --recursive
```

### 2. 创建构建脚本
创建 `build_with_bridge.ps1` 文件：

```powershell
# build_with_bridge.ps1
# RustDesk Windows Flutter 构建脚本

param(
    [switch]$SkipBridge = $false,
    [switch]$Verbose = $false
)

# 设置错误处理
$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 检查命令是否存在
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# 验证环境
Write-ColorOutput "=== 环境验证 ===" "Green"

# 检查 Rust
if (-not (Test-Command "cargo")) {
    Write-ColorOutput "错误: 未找到 cargo 命令" "Red"
    exit 1
}

# 检查 Python
if (-not (Test-Command "python3")) {
    Write-ColorOutput "错误: 未找到 python3 命令" "Red"
    exit 1
}

# 检查 Flutter
if (-not (Test-Command "flutter")) {
    Write-ColorOutput "错误: 未找到 flutter 命令" "Red"
    exit 1
}

Write-ColorOutput "环境验证通过" "Green"

# 设置环境变量
Write-ColorOutput "=== 设置环境变量 ===" "Green"
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"
$env:RUST_VERSION = "1.75"
$env:FLUTTER_VERSION = "3.24.5"

# Flutter 项目初始化
Write-ColorOutput "=== Flutter 项目初始化 ===" "Green"

if (-not (Test-Path ".\flutter\pubspec.yaml")) {
    Write-ColorOutput "Flutter 项目未初始化，正在初始化..." "Yellow"
    Push-Location flutter
    flutter create . --platforms=windows,android,ios,macos,linux
    Pop-Location
}

# 获取 Flutter 依赖
Write-ColorOutput "正在获取 Flutter 依赖..." "Green"
Push-Location flutter
flutter pub get
Pop-Location

# 创建必要的目录
Write-ColorOutput "正在创建必要的目录..." "Green"
$directories = @(
    ".\flutter\.dart_tool",
    ".\flutter\lib",
    ".\flutter\macos\Runner",
    ".\flutter\ios\Runner"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-ColorOutput "创建目录: $dir" "Cyan"
    }
}

# Bridge 文件生成
if (-not $SkipBridge) {
    Write-ColorOutput "=== 生成 Bridge 文件 ===" "Green"
    
    # 安装 flutter_rust_bridge_codegen
    Write-ColorOutput "正在安装 flutter_rust_bridge_codegen..." "Green"
    cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
    
    # 查找工具路径
    $bridge_tool = "$env:USERPROFILE\.cargo\bin\flutter_rust_bridge_codegen.exe"
    
    if (Test-Path $bridge_tool) {
        Write-ColorOutput "找到 flutter_rust_bridge_codegen: $bridge_tool" "Green"
        
        # 显示当前工作目录
        Write-ColorOutput "当前工作目录: $(Get-Location)" "Yellow"
        
        # 生成 bridge 文件
        Write-ColorOutput "正在生成 bridge 文件..." "Green"
        $command = @(
            $bridge_tool,
            "--rust-input", ".\src\flutter_ffi.rs",
            "--dart-output", ".\flutter\lib\generated_bridge.dart",
            "--c-output", ".\flutter\macos\Runner\bridge_generated.h"
        )
        
        if ($Verbose) {
            Write-ColorOutput "执行命令: $($command -join ' ')" "Yellow"
        }
        
        $result = & $bridge_tool `
            --rust-input .\src\flutter_ffi.rs `
            --dart-output .\flutter\lib\generated_bridge.dart `
            --c-output .\flutter\macos\Runner\bridge_generated.h `
            2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Bridge 文件生成成功！" "Green"
            
            # 复制头文件
            if (Test-Path ".\flutter\macos\Runner\bridge_generated.h") {
                Copy-Item ".\flutter\macos\Runner\bridge_generated.h" ".\flutter\ios\Runner\bridge_generated.h"
                Write-ColorOutput "头文件复制成功！" "Green"
            }
            
            # 检查生成的文件
            $generated_files = @(
                ".\src\bridge_generated.rs",
                ".\flutter\lib\generated_bridge.dart",
                ".\flutter\lib\generated_bridge.freezed.dart"
            )
            
            foreach ($file in $generated_files) {
                if (Test-Path $file) {
                    Write-ColorOutput "✓ $file" "Green"
                } else {
                    Write-ColorOutput "⚠ $file 未生成" "Yellow"
                }
            }
        } else {
            Write-ColorOutput "错误：Bridge 文件生成失败" "Red"
            Write-ColorOutput "输出: $result" "Red"
            exit 1
        }
    } else {
        Write-ColorOutput "错误：找不到 flutter_rust_bridge_codegen" "Red"
        exit 1
    }
} else {
    Write-ColorOutput "跳过 Bridge 文件生成" "Yellow"
}

# 主构建
Write-ColorOutput "=== 开始主构建 ===" "Green"
Write-ColorOutput "执行命令: python3 .\build.py --portable --hwcodec --flutter --vram --skip-portable-pack" "Yellow"

try {
    python3 .\build.py --portable --hwcodec --flutter --vram --skip-portable-pack
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "构建成功完成！" "Green"
        
        # 检查构建产物
        $build_artifacts = @(
            ".\target\release\rustdesk.exe",
            ".\flutter\build\windows\x64\runner\Release"
        )
        
        foreach ($artifact in $build_artifacts) {
            if (Test-Path $artifact) {
                Write-ColorOutput "✓ 构建产物: $artifact" "Green"
            }
        }
    } else {
        Write-ColorOutput "构建失败，退出码: $LASTEXITCODE" "Red"
        exit 1
    }
} catch {
    Write-ColorOutput "构建过程中发生错误: $($_.Exception.Message)" "Red"
    exit 1
}

Write-ColorOutput "=== 构建完成 ===" "Green"
```

## 构建流程详解

### 1. 环境验证阶段
- 检查 Rust、Python、Flutter 等必需工具
- 验证版本兼容性
- 设置必要的环境变量

### 2. Flutter 项目初始化
- 检查 Flutter 项目状态
- 初始化 Flutter 项目（如需要）
- 获取 Flutter 依赖包
- 创建必要的目录结构

### 3. Bridge 文件生成
- 安装 `flutter_rust_bridge_codegen` 工具
- 生成 Rust-Dart FFI 绑定文件：
  - `src/bridge_generated.rs` - Rust FFI 绑定
  - `flutter/lib/generated_bridge.dart` - Dart FFI 绑定
  - `flutter/lib/generated_bridge.freezed.dart` - Freezed 代码生成
  - `flutter/macos/Runner/bridge_generated.h` - C 头文件
  - `flutter/ios/Runner/bridge_generated.h` - iOS 头文件

### 4. 主构建阶段
- 执行 `build.py` 脚本
- 编译 Rust 核心代码
- 构建 Flutter 应用
- 生成最终的可执行文件

## 构建命令参数说明

### build.py 参数
```powershell
python3 .\build.py --portable --hwcodec --flutter --vram --skip-portable-pack
```

- `--portable`: 生成便携版本
- `--hwcodec`: 启用硬件编解码器支持
- `--flutter`: 启用 Flutter 前端
- `--vram`: 启用 VRAM 支持
- `--skip-portable-pack`: 跳过便携包打包

## 常见问题解决

### 1. Bridge 文件生成失败

**问题**: `flutter_rust_bridge_codegen` 无反应或失败

**解决方案**:
```powershell
# 清理 Flutter 项目
cd flutter
flutter clean
flutter pub get
cd ..

# 重新创建目录
New-Item -ItemType Directory -Path ".\flutter\.dart_tool" -Force
New-Item -ItemType Directory -Path ".\flutter\lib" -Force
```

### 2. 依赖问题

**问题**: 缺少必要的依赖

**解决方案**:
```powershell
# 更新 Rust 工具链
rustup update

# 重新安装 flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked --force
```

### 3. 编译错误

**问题**: Rust 编译错误

**解决方案**:
```powershell
# 清理构建缓存
cargo clean

# 检查 Rust 版本
rustc --version

# 更新依赖
cargo update
```

### 4. Flutter 问题

**问题**: Flutter 构建失败

**解决方案**:
```powershell
# 检查 Flutter 环境
flutter doctor -v

# 清理 Flutter 缓存
flutter clean

# 重新获取依赖
flutter pub get
```

## 构建产物

成功构建后，您将在以下位置找到构建产物：

### 主要可执行文件
- `target/release/rustdesk.exe` - 主要的可执行文件

### Flutter 构建产物
- `flutter/build/windows/x64/runner/Release/` - Flutter Windows 构建目录
  - `rustdesk.exe` - Flutter 应用可执行文件
  - `flutter_windows.dll` - Flutter 运行时库
  - 其他必要的 DLL 和资源文件

## 验证构建

### 1. 检查生成的文件
```powershell
# 检查 Bridge 文件
Get-ChildItem ".\src\bridge_generated.rs"
Get-ChildItem ".\flutter\lib\generated_bridge.dart"

# 检查构建产物
Get-ChildItem ".\target\release\rustdesk.exe"
Get-ChildItem ".\flutter\build\windows\x64\runner\Release\"
```

### 2. 运行测试
```powershell
# 运行 RustDesk 可执行文件
.\target\release\rustdesk.exe

# 或运行 Flutter 版本
.\flutter\build\windows\x64\runner\Release\rustdesk.exe
```

## 性能优化建议

### 1. 构建优化
- 使用 SSD 存储以提高 I/O 性能
- 增加系统内存以减少交换文件使用
- 关闭不必要的后台程序

### 2. 开发环境优化
```powershell
# 设置 Cargo 增量编译
$env:CARGO_INCREMENTAL = "1"

# 设置并行编译作业数
$env:CARGO_BUILD_JOBS = "4"  # 根据 CPU 核心数调整
```

## 故障排除

### 日志分析
如果构建失败，请检查以下日志：
- Cargo 构建日志
- Flutter 构建日志
- PowerShell 执行日志

### 调试模式
使用 `-Verbose` 参数获取详细输出：
```powershell
.\build_with_bridge.ps1 -Verbose
```

### 跳过 Bridge 生成
如果 Bridge 文件已存在且正确，可以跳过生成步骤：
```powershell
.\build_with_bridge.ps1 -SkipBridge
```

## 总结

本指南提供了完整的 RustDesk Windows Flutter 构建流程，包括：

1. **环境准备**: 安装所有必需的软件和工具
2. **环境配置**: 设置正确的环境变量和路径
3. **项目初始化**: 克隆代码库并准备构建环境
4. **自动化构建**: 使用提供的 PowerShell 脚本自动化整个构建过程
5. **问题解决**: 常见问题的诊断和解决方案

遵循本指南，您应该能够成功构建 RustDesk 的 Windows Flutter 版本。如果遇到问题，请参考故障排除部分或查看相关的错误日志。
