import 'package:flutter/material.dart';

import '../../core/help/help_topics.dart';
import 'confirm_bottom_sheet.dart';

/// 页面右上角的「?」小图标：点开当前功能的解释弹层。
/// 文案统一放 [HelpTopics]，这里只负责按钮样式与弹出。——来自Trae
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.topic});

  final ({String title, String body}) topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: topic.title,
      icon: Icon(
        Icons.help_outline,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () =>
          showInfoSheet(context, title: topic.title, message: topic.body),
    );
  }
}
