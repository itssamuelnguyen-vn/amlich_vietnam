import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/backup.dart';

/// Renders the RepaintBoundary under [key] to a PNG and opens Android's share sheet with it and [text].
/// Returns false when there is nothing to capture or sharing is unavailable (tests).
Future<bool> shareBoundary(GlobalKey key, String text) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return false;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) return false;
  try {
    await FilePicker.shareImage(data.buffer.asUint8List(), text);
    return true;
  } on MissingPluginException {
    return false;
  }
}
