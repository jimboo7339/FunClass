import 'package:flutter/material.dart';

import '../../features/settings/presentation/settings_page.dart';

/// AppBar 右上角齿轮按钮，点击跳转设置页
/// 来自Trae
Widget buildSettingsGear(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: '设置',
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    },
  );
}
