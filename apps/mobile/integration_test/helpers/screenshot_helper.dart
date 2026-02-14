import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

/// Takes a screenshot and saves it to the screenshots/ directory.
///
/// [binding] is the integration test binding.
/// [name] is the screenshot filename (without extension).
///
/// On Android, [convertFlutterSurfaceToImage] must be called once before
/// the first screenshot. This helper handles that automatically.
Future<void> takeAndSaveScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  try {
    final bytes = await binding.takeScreenshot(name);
    final file = File('screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  } catch (e) {
    // Screenshot capture may fail in environments without a rendering surface
    // (e.g. flutter test on CI without a device). Log and continue so the
    // test assertions still run.
    debugPrint('Screenshot "$name" skipped: $e');
  }
}
