# RustDesk 命令行参数用法文档

RustDesk 是一个开源的远程桌面软件，支持多种命令行参数来实现不同的功能。

## 基本用法

```bash
rustdesk [参数] [值]
```

## 通用参数

### 版本信息
- `--version` - 显示 RustDesk 版本号
- `--build-date` - 显示构建日期

### 连接相关参数

#### 远程连接
- `--connect <远程ID>` - 连接到指定的远程设备
- `--play <远程ID>` - 播放模式连接（只查看，不控制）
- `--file-transfer <远程ID>` - 打开文件传输窗口
- `--view-camera <远程ID>` - 查看远程摄像头
- `--port-forward <远程ID>` - 端口转发
- `--rdp <远程ID>` - RDP 连接

#### 连接选项
- `--password <密码>` - 连接时使用的密码
- `--relay` - 强制使用中继连接
- `--switch_uuid <UUID>` - 切换 UUID（内部使用）

### 服务相关参数

#### 服务管理
- `--service` - 以服务模式启动 RustDesk
- `--server` - 启动服务器模式
- `--install-service` - 安装 RustDesk 服务
- `--uninstall-service` - 卸载 RustDesk 服务
- `--no-server` - 启动时不启动服务器

#### 系统托盘
- `--tray` - 启动系统托盘

### 安装和更新参数

#### 安装相关
- `--install` - 安装 RustDesk（Windows 自动触发）
- `--silent-install` - 静默安装
- `--uninstall` - 卸载 RustDesk
- `--noinstall` - 跳过安装
- `--after-install` - 安装后执行
- `--before-uninstall` - 卸载前执行

#### 更新相关
- `--update` - 更新 RustDesk 到最新版本

### 配置管理参数

#### 基本配置
- `--import-config <配置文件路径>` - 导入配置文件
- `--config <配置字符串>` - 设置自定义服务器配置
- `--option [选项名] [选项值]` - 获取或设置配置选项
  - 只提供选项名：获取选项值
  - 提供选项名和值：设置选项

#### 身份和密码管理
- `--get-id` - 获取设备 ID
- `--set-id <新ID>` - 设置设备 ID
- `--password <密码>` - 设置永久密码
- `--set-unlock-pin <PIN码>` - 设置解锁 PIN 码

#### 设备分配（企业功能）
```bash
--assign --token <令牌> [其他选项]
```
支持的选项：
- `--user_name <用户名>` - 分配给指定用户
- `--strategy_name <策略名>` - 应用指定策略
- `--address_book_name <地址簿名>` - 添加到地址簿
- `--address_book_tag <标签>` - 地址簿标签
- `--address_book_alias <别名>` - 地址簿别名
- `--device_group_name <设备组名>` - 添加到设备组

### 连接管理器

- `--cm` - 启动连接管理器（带界面）
- `--cm-no-ui` - 启动连接管理器（无界面）

### 特殊功能参数

#### 权限相关（Windows）
- `--elevate` - 提升权限运行
- `--run-as-system` - 以系统用户身份运行
- `--quick_support` - 快速支持模式
- `--portable-service` - 便携服务模式

#### 虚拟显示器（Windows）
- `--install-idd` - 安装虚拟显示器驱动
- `--uninstall-amyuni-idd` - 卸载 Amyuni 虚拟显示器驱动

#### 远程打印（Windows）
- `--install-remote-printer` - 安装远程打印机
- `--uninstall-remote-printer` - 卸载远程打印机

#### 证书管理（Windows）
- `--uninstall-cert` - 卸载证书

#### 硬件编解码
- `--check-hwcodec-config` - 检查硬件编解码配置

### 插件管理

- `--plugin-install <插件ID> [下载URL]` - 安装插件
- `--plugin-uninstall <插件ID>` - 卸载插件

### 系统相关参数

#### Linux 特有
- `-gtk-sudo` - GTK sudo 执行（Linux）

#### 文件操作
- `--remove <文件路径>` - 删除指定文件

## 命令行模式（CLI 特性）

当启用 CLI 特性时，支持以下参数：

- `-p, --port-forward=<选项>` - 端口转发，格式：`远程ID:本地端口:远程端口[:远程主机]`
- `-c, --connect=<远程ID>` - 连接到远程设备（测试用）
- `-k, --key=<密钥>` - 指定连接密钥
- `-s, --server` - 启动服务器

### 端口转发示例

```bash
# 将本地 8080 端口转发到远程设备的 80 端口
rustdesk --port-forward "远程设备ID:8080:80"

# 转发到远程设备的特定主机
rustdesk --port-forward "远程设备ID:8080:80:localhost"
```

## 使用示例

### 基本连接
```bash
# 连接到远程设备
rustdesk --connect 123456789

# 使用密码连接
rustdesk --connect 123456789 --password mypassword

# 文件传输
rustdesk --file-transfer 123456789
```

### 服务管理
```bash
# 安装服务
sudo rustdesk --install-service

# 启动服务器
rustdesk --server

# 启动托盘
rustdesk --tray
```

### 配置管理
```bash
# 获取设备 ID
rustdesk --get-id

# 设置永久密码
sudo rustdesk --password "mypassword"

# 设置配置选项
sudo rustdesk --option "auto-login" "Y"

# 获取配置选项
rustdesk --option "auto-login"
```

### 企业分配
```bash
# 将设备分配给用户
sudo rustdesk --assign --token "your_token" --user_name "john_doe"

# 分配到设备组
sudo rustdesk --assign --token "your_token" --device_group_name "IT_Department"
```

## 权限要求

某些操作需要管理员权限：
- 设置永久密码
- 设置设备 ID
- 配置选项管理
- 设备分配
- 服务安装/卸载

在 Linux/macOS 上使用 `sudo`，在 Windows 上以管理员身份运行。

## 注意事项

1. 大部分参数在不同平台上可能有不同的行为
2. 某些功能（如虚拟显示器、远程打印）仅在 Windows 上可用
3. 企业功能需要有效的许可证和令牌
4. 使用 `--help` 可能不会显示所有参数，因为 RustDesk 使用自定义参数解析

## 版权信息

RustDesk 由 Purslane Ltd 开发维护。
官方网站: https://rustdesk.com
