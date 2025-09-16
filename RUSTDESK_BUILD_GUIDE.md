# RustDesk Windows 和 macOS 构建指南

本指南基于官方的 GitHub Actions CI 配置，详细说明如何在 Windows 和 macOS 平台构建 RustDesk。

## 环境变量

以下是构建过程中使用的重要版本信息：

```bash
# Rust 版本
SCITER_RUST_VERSION="1.75"
RUST_VERSION="1.75"
MAC_RUST_VERSION="1.81"

# Flutter 版本
FLUTTER_VERSION="3.24.5"

# LLVM 版本
LLVM_VERSION="15.0.6"

# VCPKG 版本
VCPKG_COMMIT_ID="6f29f12e82a8293156836ad81cc9bf5af41fe836"

# 应用版本
VERSION="1.4.2"
```

---

## Windows 构建指南

### 前置条件

1. **操作系统**：Windows 10/11 或 Windows Server 2022
2. **Git**：安装 Git 并确保可以访问子模块
3. **Python3**：用于运行构建脚本

### 步骤 1：环境准备

#### 1.1 克隆代码仓库

```powershell
git clone --recursive https://github.com/rustdesk/rustdesk.git
cd rustdesk
```

#### 1.2 安装 LLVM 和 Clang

从 [LLVM 官网](https://github.com/llvm/llvm-project/releases) 下载并安装 LLVM 15.0.6：

```powershell
# 或者使用 Chocolatey
choco install llvm --version=15.0.6
```

#### 1.3 安装 Flutter

从 [Flutter 官网](https://flutter.dev/docs/get-started/install/windows) 下载 Flutter 3.24.5：

```powershell
# 下载 Flutter
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip" -OutFile "flutter.zip"
Expand-Archive flutter.zip -DestinationPath D:\dev\devtools
$env:PATH += ";D:\dev\devtools\flutter\bin"

# 验证安装
flutter doctor -v
flutter precache --windows
```

#### 1.4 替换 RustDesk 自定义 Flutter 引擎

```powershell
# 下载自定义引擎
Invoke-WebRequest -Uri "https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip" -OutFile "windows-x64-release.zip"
Expand-Archive -Path windows-x64-release.zip -DestinationPath windows-x64-release

# 替换引擎文件
$flutterPath = (Get-Command flutter).Source
$enginePath = Join-Path (Split-Path (Split-Path $flutterPath)) "bin\cache\artifacts\engine\windows-x64-release"
Move-Item -Path "windows-x64-release\*" -Destination $enginePath -Force
```

#### 1.5 应用 Flutter 补丁

```bash
# 在 Git Bash 中执行
cp .github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff $(dirname $(dirname $(which flutter)))
cd $(dirname $(dirname $(which flutter)))
git apply flutter_3.24.4_dropdown_menu_enableFilter.diff
```

#### 1.6 安装 Rust 工具链

```powershell
# 安装 rustup
Invoke-WebRequest -Uri "https://win.rustup.rs/" -OutFile "rustup-init.exe"
.\rustup-init.exe -y

# 重启 PowerShell 或重新加载环境变量
$env:PATH += ";$env:USERPROFILE\.cargo\bin"

# 安装指定版本的 Rust
rustup toolchain install 1.75.0
rustup default 1.75.0
rustup target add x86_64-pc-windows-msvc
rustup component add rustfmt
```

#### 1.7 设置 vcpkg

```powershell
# 克隆 vcpkg
git clone https://github.com/Microsoft/vcpkg.git D:\dev\devtools\vcpkg
cd D:\dev\devtools\vcpkg
git checkout 6f29f12e82a8293156836ad81cc9bf5af41fe836

# 安装 vcpkg
.\bootstrap-vcpkg.bat

# 设置环境变量
$env:VCPKG_ROOT = "D:\dev\devtools\vcpkg"
$env:VCPKG_DEFAULT_HOST_TRIPLET = "x64-windows-static"
```

### 步骤 2：安装依赖

```powershell
# 安装 vcpkg 依赖
D:\dev\devtools\vcpkg install --triplet x64-windows-static --x-install-root="D:\dev\devtools\vcpkg\installed"
```

### 步骤 3：构建 RustDesk

#### 3.1 主要构建

```powershell
# 构建主程序
# 直接构建
python3 .\build.py --portable --hwcodec --flutter --vram

# 如需额外组件
python3 .\build.py --portable --hwcodec --flutter --vram --skip-portable-pack
Copy-Item .\flutter\build\windows\x64\runner\Release\ .\rustdesk -R
```

#### 3.2 下载额外组件

```powershell
# 下载 USB MIDD 驱动
Invoke-WebRequest -Uri "https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip" -OutFile "usbmmidd_v2.zip"
Expand-Archive usbmmidd_v2.zip -DestinationPath .
Remove-Item -Path "usbmmidd_v2\Win32" -Recurse
Remove-Item -Path "usbmmidd_v2\deviceinstaller64.exe", "usbmmidd_v2\deviceinstaller.exe", "usbmmidd_v2\usbmmidd.bat"
Move-Item .\usbmmidd_v2 .\rustdesk

# 下载打印机驱动（可选）
try {
    Invoke-WebRequest -Uri "https://github.com/rustdesk/hbb_common/releases/download/driver/rustdesk_printer_driver_v4-1.4.zip" -OutFile "rustdesk_printer_driver_v4-1.4.zip"
    Invoke-WebRequest -Uri "https://github.com/rustdesk/hbb_common/releases/download/driver/printer_driver_adapter.zip" -OutFile "printer_driver_adapter.zip"
    Invoke-WebRequest -Uri "https://github.com/rustdesk/hbb_common/releases/download/driver/sha256sums" -OutFile "sha256sums"
    
    # 验证校验和并解压
    $checksum_driver = (Select-String -Path .\sha256sums -Pattern '^([a-fA-F0-9]{64}) \*rustdesk_printer_driver_v4-1.4\.zip$').Matches.Groups[1].Value
    $downloadsum_driver = Get-FileHash -Path rustdesk_printer_driver_v4-1.4.zip -Algorithm SHA256
    
    if ($checksum_driver -eq $downloadsum_driver.Hash) {
        Expand-Archive rustdesk_printer_driver_v4-1.4.zip -DestinationPath .
        mkdir .\rustdesk\drivers
        Move-Item .\rustdesk_printer_driver_v4-1.4 .\rustdesk\drivers\RustDeskPrinterDriver
        Expand-Archive printer_driver_adapter.zip -DestinationPath .
        Move-Item .\printer_driver_adapter.dll .\rustdesk
    }
} catch {
    Write-Host "忽略打印机驱动下载错误"
}
```

### 步骤 4：创建安装包（可选）

#### 4.1 创建便携式可执行文件

```powershell
# 创建自解压可执行文件
# 编辑 res/manifest.xml，移除 dpiAware 行
(Get-Content res\manifest.xml) | Where-Object { $_ -notmatch 'dpiAware' } | Set-Content res\manifest.xml

Set-Location .\libs\portable
pip3 install -r requirements.txt
python3 .\generate.py -f ..\..\rustdesk\ -o . -e ..\..\rustdesk\rustdesk.exe
Set-Location ..\..

# mkdir SignOutput
Move-Item .\target\release\rustdesk-portable-packer.exe .\SignOutput\rustdesk-1.4.2-x86_64.exe
```

#### 4.2 创建 MSI 安装包

```powershell
# 安装 MSBuild（通常随 Visual Studio 安装）
# 构建 MSI
Set-Location .\res\msi
python preprocess.py --arp -d ..\..\rustdesk
nuget restore msi.sln
msbuild msi.sln -p:Configuration=Release -p:Platform=x64 /p:TargetVersion=Windows10
Move-Item .\Package\bin\x64\Release\en-us\Package.msi ..\..\SignOutput\rustdesk-1.4.2-x86_64.msi
Set-Location ..\..
```

---

## macOS 构建指南

### 前置条件

1. **操作系统**：macOS 12.3+ (对于 Apple Silicon) 或 macOS 10.15+ (对于 Intel)
2. **Xcode**：最新版本的 Xcode 和 Command Line Tools
3. **Homebrew**：用于安装依赖

### 步骤 1：环境准备

#### 1.1 克隆代码仓库

```bash
git clone --recursive https://github.com/rustdesk/rustdesk.git
cd rustdesk
```

#### 1.2 安装系统依赖

```bash
# 安装 Homebrew（如果尚未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装构建依赖
brew install llvm create-dmg nasm cmake gcc wget ninja

# 检查并安装 pkg-config（可能已预装）
if ! command -v pkg-config &> /dev/null; then
    brew install pkg-config
fi
```

#### 1.3 安装 Flutter

```bash
# 下载 Flutter
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.5-stable.zip
unzip flutter_macos_3.24.5-stable.zip
sudo mv flutter /opt/flutter
export PATH="/opt/flutter/bin:$PATH"

# 验证安装
flutter doctor -v
```

#### 1.4 应用 Flutter 补丁

```bash
cd $(dirname $(dirname $(which flutter)))
git apply /path/to/rustdesk/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff
cd /path/to/rustdesk
```

#### 1.5 修复 Flutter 调度器问题

```bash
cd "$(dirname "$(which flutter)")"
# 注释掉导致问题的行
sed -i -e 's/_setFramesEnabledState(false);/\/\/_setFramesEnabledState(false);/g' ../packages/flutter/lib/src/scheduler/binding.dart
```

#### 1.6 安装 Rust 工具链

```bash
# 安装 rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 安装指定版本（macOS 需要 1.81）
rustup toolchain install 1.81.0
rustup default 1.81.0

# 添加目标平台
# 对于 Intel Mac
rustup target add x86_64-apple-darwin
# 对于 Apple Silicon Mac
rustup target add aarch64-apple-darwin

rustup component add rustfmt
```

#### 1.7 设置 vcpkg

```bash
# 克隆 vcpkg
git clone https://github.com/Microsoft/vcpkg.git /opt/vcpkg
cd /opt/vcpkg
git checkout 6f29f12e82a8293156836ad81cc9bf5af41fe836

# 引导 vcpkg
./bootstrap-vcpkg.sh

# 设置环境变量
export VCPKG_ROOT="/opt/vcpkg"
```

### 步骤 2：安装依赖

```bash
# 安装 vcpkg 依赖
$VCPKG_ROOT/vcpkg install --x-install-root="$VCPKG_ROOT/installed"
```

### 步骤 3：构建 RustDesk

#### 3.1 设置最低 macOS 版本（仅适用于 Apple Silicon）

```bash
# 如果构建 Apple Silicon 版本
if [[ "$(uname -m)" == "arm64" ]]; then
    MIN_MACOS_VERSION="12.3"
    sed -i -e "s/MACOSX_DEPLOYMENT_TARGET\=[0-9]*.[0-9]*/MACOSX_DEPLOYMENT_TARGET=${MIN_MACOS_VERSION}/" build.py
    sed -i -e "s/platform :osx, '.*'/platform :osx, '${MIN_MACOS_VERSION}'/" flutter/macos/Podfile
    sed -i -e "s/osx_minimum_system_version = \"[0-9]*.[0-9]*\"/osx_minimum_system_version = \"${MIN_MACOS_VERSION}\"/" Cargo.toml
    sed -i -e "s/MACOSX_DEPLOYMENT_TARGET = [0-9]*.[0-9]*;/MACOSX_DEPLOYMENT_TARGET = ${MIN_MACOS_VERSION};/" flutter/macos/Runner.xcodeproj/project.pbxproj
fi
```

#### 3.2 主要构建

```bash
# 构建主程序
# 对于 Intel Mac
./build.py --flutter --hwcodec --unix-file-copy-paste

# 对于 Apple Silicon Mac
./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit
```

### 步骤 4：创建 DMG 包

#### 4.1 创建未签名的 DMG

```bash
# 修复 create-dmg 脚本的重试次数
CREATE_DMG="$(command -v create-dmg)"
CREATE_DMG="$(readlink -f "$CREATE_DMG")"
sudo sed -i -e 's/MAXIMUM_UNMOUNTING_ATTEMPTS=3/MAXIMUM_UNMOUNTING_ATTEMPTS=7/' "$CREATE_DMG"

# 创建 DMG
create-dmg \
    --icon "RustDesk.app" 200 190 \
    --hide-extension "RustDesk.app" \
    --window-size 800 400 \
    --app-drop-link 600 185 \
    rustdesk-1.4.2-$(uname -m).dmg \
    ./flutter/build/macos/Build/Products/Release/RustDesk.app
```

### 步骤 5：代码签名和公证（可选）

> **注意**：代码签名需要 Apple Developer 账户和相应的证书。

#### 5.1 导入签名证书

```bash
# 如果你有 .p12 证书文件
security import /path/to/certificate.p12 -k ~/Library/Keychains/login.keychain-db -P <password>
```

#### 5.2 签名应用和 DMG

```bash
    # 签名应用
    codesign --force --options runtime \
        -s "Developer ID Application: Your Name (TEAM_ID)" \
        --deep --strict \
        ./flutter/build/macos/Build/Products/Release/RustDesk.app -vvv

    # 重新创建并签名 DMG
    rm -rf *.dmg
    create-dmg \
        --icon "RustDesk.app" 200 190 \
        --hide-extension "RustDesk.app" \
        --window-size 800 400 \
        --app-drop-link 600 185 \
        rustdesk-1.4.2.dmg \
        ./flutter/build/macos/Build/Products/Release/RustDesk.app

    codesign --force --options runtime \
        -s "Developer ID Application: Your Name (TEAM_ID)" \
        --deep --strict rustdesk-1.4.2.dmg -vvv
```

#### 5.3 公证（需要 Apple ID 和应用专用密码）

```bash
# 使用 xcrun notarytool 进行公证
xcrun notarytool submit rustdesk-1.4.2.dmg \
    --apple-id "your-apple-id@example.com" \
    --password "app-specific-password" \
    --team-id "TEAM_ID" \
    --wait

# 装订公证票据
xcrun stapler staple rustdesk-1.4.2.dmg
```

---

## 故障排除

### Windows 常见问题

1. **vcpkg 安装失败**
   - 确保有足够的磁盘空间（至少 10GB）
   - 检查网络连接是否稳定
   - 尝试使用代理或更换网络

2. **Flutter 引擎替换失败**
   - 确保 Flutter 安装路径正确
   - 以管理员身份运行 PowerShell

3. **编译错误**
   - 检查 Rust 版本是否正确 (1.75)
   - 确保 LLVM 路径在 PATH 中
   - 清理缓存：`cargo clean`

### macOS 常见问题

1. **权限问题**
   - 使用 `sudo` 执行需要管理员权限的命令
   - 确保 Xcode 许可协议已接受

2. **网络问题**
   - 某些依赖可能需要科学上网
   - 尝试使用国内镜像源

3. **签名问题**
   - 确保证书有效且未过期
   - 检查 Team ID 是否正确

---

## 其他注意事项

1. **版本兼容性**：请严格按照指定的版本安装各组件，版本不匹配可能导致构建失败。

2. **硬件要求**：建议至少 8GB 内存和 20GB 可用磁盘空间。

3. **网络环境**：某些依赖需要从 GitHub 或其他海外服务器下载，建议确保网络连接稳定。

4. **增量构建**：首次构建后，后续修改可以使用增量构建加快速度。

5. **清理构建**：如果遇到奇怪的错误，尝试 `cargo clean` 和删除 `flutter/build` 目录重新构建。

---

## 参考资源

- [RustDesk 官方文档](https://rustdesk.com/docs/)
- [Flutter 安装指南](https://flutter.dev/docs/get-started/install)
- [Rust 安装指南](https://rustup.rs/)
- [vcpkg 文档](https://vcpkg.io/en/getting-started.html)
- [原始 CI 配置文件](.github/workflows/flutter-build.yml)

---

*本指南基于 RustDesk 的 GitHub Actions CI 配置文件创建，版本信息可能会随项目更新而变化。建议在构建前检查最新的 CI 配置文件以获取最新的版本信息。*
