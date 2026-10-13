/// 构建信息统一入口。
/// 数值来自自动生成的 build_info.g.dart（每次打包由 tool 脚本覆盖）。
/// 在设置页「关于」区域展示，用于核对是否安装正确/最新版本的安装包。
/// 来自Trae
library;

export 'build_info.g.dart'
    show buildHash, buildCommit, buildTime, appVersion, buildNumber, fullVersion;