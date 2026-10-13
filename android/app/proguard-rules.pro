# 趣课 release R8 规则
#
# flutter_local_notifications 把"已排程提醒列表"用 Gson 序列化存在 SharedPreferences 里，
# 读取时靠 `new TypeToken<ArrayList<NotificationDetails>>() {}` 的**泛型签名**反序列化。
# R8 混淆默认会剥掉匿名类的泛型签名，release 包里 pendingNotificationRequests() 就会抛
# "TypeToken must be created with a type argument"，提醒排程整个静默失败（v22 真机实锤）。
# 插件 README 明确要求宿主 App 自带这组 GSON 规则（插件不提供 consumer rules）。——来自Trae

# 保留泛型签名与注解（Gson 反射的命根子）
-keepattributes Signature
-keepattributes *Annotation*

# Gson 与 TypeToken：保留 TypeToken 及其所有匿名子类（含泛型父类引用）
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# 插件自身模型类（NotificationDetails 等靠 Gson 反射读写，字段名不能混淆）
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
