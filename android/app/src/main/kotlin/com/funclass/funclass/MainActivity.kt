package com.funclass.funclass

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 启动图标切换
 *
 * 图标不直接挂在 MainActivity 上，而是各挂一个 activity-alias（见 AndroidManifest.xml），
 * 「换图标」= 启用目标 alias、禁用其它 alias。这样不用重装 apk 就能换图标。——来自Trae
 */
class MainActivity : FlutterActivity() {

    /** 图标 id（Dart 侧用的标识）→ manifest 里的 activity-alias 名，两边必须一一对应 */
    private val iconAliases = linkedMapOf(
        "classic" to "IconClassic",
        "puzzle" to "IconPuzzle",
        "smile" to "IconSmile",
        "book" to "IconBook",
        "spark" to "IconSpark",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentIconId())
                    "setIcon" -> {
                        val id = call.argument<String>("id")
                        if (id == null || !iconAliases.containsKey(id)) {
                            result.error("bad_argument", "未知的图标 id: $id", null)
                        } else {
                            applyIcon(id)
                            result.success(currentIconId())
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** 当前生效的图标 id：找那个没被禁用的 alias */
    private fun currentIconId(): String {
        val pm = packageManager
        for ((id, alias) in iconAliases) {
            val state = pm.getComponentEnabledSetting(componentFor(alias))
            // DEFAULT 表示没在运行时改过、按 manifest 里的 enabled 走。
            // IconClassic 在 manifest 里就是 true，所以只要不是 DISABLED 就算生效。——来自Trae
            if (state != PackageManager.COMPONENT_ENABLED_STATE_DISABLED) return id
        }
        // 理论上到不了这里：万一所有 alias 都被禁了（手工改过、或旧版本遗留），
        // 把默认图标重新启用，保证桌面永远有入口。——来自Trae
        pm.setComponentEnabledSetting(
            componentFor(checkNotNull(iconAliases["classic"])),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            DONT_KILL_APP
        )
        return "classic"
    }

    private fun applyIcon(id: String) {
        val pm = packageManager
        val target = iconAliases.getValue(id)
        // 顺序不能反：先启用目标、再关掉其它。反过来会有一瞬间零个启动入口，
        // 部分启动器遇到这种情况会把图标直接抹掉且不再恢复。——来自Trae
        pm.setComponentEnabledSetting(
            componentFor(target),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            DONT_KILL_APP
        )
        for ((otherId, alias) in iconAliases) {
            if (otherId == id) continue
            pm.setComponentEnabledSetting(
                componentFor(alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                DONT_KILL_APP
            )
        }
    }

    /** alias 在 manifest 里写成 ".IconXxx"，组件全名要补上包名 */
    private fun componentFor(alias: String) =
        ComponentName(packageName, "$packageName.$alias")

    companion object {
        private const val CHANNEL = "com.funclass.funclass/app_icon"

        /** setComponentEnabledSetting 的 flag：0 = 不杀掉当前进程 */
        private const val DONT_KILL_APP = 0
    }
}
