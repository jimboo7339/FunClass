# 趣课 FunClass

课外兴趣课管理 App。帮你管理孩子的兴趣班：录入课程与学员、跟踪剩余课时、查看每日课表、统计上课记录，并通过本地通知在课前提醒，支持 WebDAV 云备份。

纯本地应用，所有数据存储在设备上的 SQLite 数据库中，不依赖任何服务端。

## 功能特性

- **今日**：当天要上的课一览，快速点一下就完成签到打卡
- **课程管理**：录入兴趣班课程，支持按周期排课、调课、加课（临时加的一节会作为额外课次插入，不与常规排课合并）
- **学员管理**：每门课的学员名单与剩余课时跟踪，课时用完提前可见
- **日历**：月视图浏览全部课次安排
- **统计**：图表展示上课次数、课时消耗等趋势
- **课次提醒**：课前固定提前量本地通知，无需网络
- **WebDAV 备份**：手动或自动上传备份到坚果云等 WebDAV 网盘，备份文件按版本命名；WebDAV 密码仅存于系统安全存储（Keystore / Keychain）
- **液态玻璃 UI**：Liquid Glass 风格界面，支持强调色自定义与多套可切换桌面图标

## 技术栈

| 组件 | 选型 |
|---|---|
| 框架 | Flutter（Dart SDK ^3.9.2），主要面向 Android |
| 数据库 | Drift (SQLite) + drift_flutter，代码生成 |
| 状态管理 | flutter_riverpod |
| 通知 | flutter_local_notifications + timezone |
| 日历 / 图表 | table_calendar / fl_chart |
| 备份 | webdav_client + share_plus + file_picker |
| 安全存储 | flutter_secure_storage |
| UI | liquid_glass_easy（液态玻璃） |

## 项目结构

```
lib/
├── main.dart          # 入口：初始化通知、主题、排课收敛、自动备份
├── app.dart           # 根组件与导航
├── core/              # 主题、常量、通知服务、构建信息、通用组件
├── data/              # Drift 数据库、模型、仓库层
├── features/          # 按功能划分的页面
│   ├── today/         # 今日课表
│   ├── courses/       # 课程管理
│   ├── members/       # 学员管理
│   ├── calendar/      # 日历
│   ├── statistics/    # 统计
│   └── settings/      # 设置（主题、图标、备份、通知）
└── shared/            # 跨功能共享的 providers 与 widgets
tool/                  # 开发脚本（打包、构建信息生成、图标流水线）
```

## 快速开始

### 环境要求

- Flutter SDK（Dart ^3.9.2）
- Android SDK / Android Studio（Android 构建需要）

### 运行

```bash
git clone https://github.com/jimboo7339/FunClass.git
cd FunClass
flutter pub get

# 生成 Drift 数据库代码（修改表结构后需要重新执行）
dart run build_runner build --delete-conflicting-outputs

flutter run
```

> 注意：`lib/core/build_info.g.dart` 由脚本生成。若拉取后缺失该文件导致编译失败，执行一次 `dart run tool/gen_build_info.dart` 即可。

### 打包 APK

项目自带发布打包脚本，会自动生成构建哈希与递增的构建编号（保证覆盖安装）、输出带版本号的 APK 文件名并打印 SHA-256：

```bash
bash tool/build_apk.sh            # release 包
bash tool/build_apk.sh --debug    # 调试包
bash tool/build_apk.sh --split    # 按 ABI 拆分
```

产物位于 `build/app/outputs/flutter-apk/`。

### GitHub Actions 自动构建

仓库内置流水线 `.github/workflows/release.yml`，在 GitHub 云端构建 release APK 并发布：

- **打 tag 触发**：推送 `v` 开头的 tag（如 `v1.0.3`）即自动构建，并在 Releases 页创建带 APK 与 SHA-256 校验文件的 Release
- **手动触发**：Actions 页面 Run workflow，构建结果保存为 workflow artifact

签名说明：默认用 CI 临时 debug 签名（可安装，但每次密钥不同、无法覆盖安装旧版）。正式发布请在仓库 **Settings → Secrets and variables → Actions** 配置 4 个 secrets：

| Secret | 内容 |
|---|---|
| `FUNCLASS_KEYSTORE_BASE64` | keystore 文件的 base64（`base64 -w0 xxx.jks`） |
| `FUNCLASS_STORE_PASSWORD` | keystore 密码 |
| `FUNCLASS_KEY_ALIAS` | key 别名 |
| `FUNCLASS_KEY_PASSWORD` | key 密码 |

配置后流水线自动改用正式签名，构建编号从 1000 起单调递增，保证覆盖安装不被系统拒绝。

### 图标

各平台默认图标通过 `dart run flutter_launcher_icons` 生成；设置页内可切换的四款备用桌面图标（拼图/笑脸/书本/火花）由 `tool/icon_design/` 下的 Python 脚本维护，两套流水线互不影响。

## 数据与备份

- 所有课次、学员数据保存在设备本地 SQLite（Drift）
- 「设置 → 备份」支持导出文件、系统分享，或配置 WebDAV 自动同步
- WebDAV 账户密码只写入 flutter_secure_storage，不进入数据库与备份文件
- 备份文件名带版本号，恢复时兼容旧版本格式

## License

仅供个人学习与使用。
