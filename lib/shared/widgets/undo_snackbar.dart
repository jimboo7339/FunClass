import 'package:flutter/material.dart';

/// 带撤销操作的 SnackBar
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: '撤销', onPressed: onUndo),
    ),
  );
}

/// 带自定义 action 的 SnackBar
void showActionSnackBar(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: actionLabel, onPressed: onAction),
    ),
  );
}
