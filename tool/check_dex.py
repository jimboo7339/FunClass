"""检查 release APK 的 dex 里，通知插件与 Gson TypeToken 的类名是否被 R8 保留。

flutter_local_notifications 的 pendingNotificationRequests 依赖
`new TypeToken<ArrayList<NotificationDetails>>(){}` 的泛型签名；
若这些类被混淆/剥离，release 包会抛
"TypeToken must be created with a type argument"，提醒静默失败。
保留判据：dex 里能原样找到这些类描述符。——来自Trae
"""
import sys
import zipfile

APK = sys.argv[1] if len(sys.argv) > 1 else "build/app/outputs/flutter-apk/app-release.apk"

PATTERNS = [
    "com/dexterous/flutterlocalnotifications/models/NotificationDetails",
    "com/google/gson/reflect/TypeToken",
    "com/dexterous/flutterlocalnotifications/FlutterLocalNotificationsPlugin",
]

z = zipfile.ZipFile(APK)
dex_names = [n for n in z.namelist() if n.startswith("classes") and n.endswith(".dex")]
blob = b"".join(z.read(n) for n in dex_names)

ok = True
for p in PATTERNS:
    hit = p.encode() in blob
    print(("KEPT    " if hit else "MISSING ") + p)
    ok = ok and hit

sys.exit(0 if ok else 1)
