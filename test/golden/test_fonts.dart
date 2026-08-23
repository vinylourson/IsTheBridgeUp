import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled pixel fonts into the test renderer.
///
/// Without this, goldens render in the test harness's placeholder font and
/// every glyph is a solid block — which hides exactly what we want to check,
/// including whether the French accents have real glyphs.
Future<void> loadPixelFonts() async {
  const Map<String, String> fonts = <String, String>{
    'PressStart2P': 'assets/fonts/PressStart2P-Regular.ttf',
    'Silkscreen': 'assets/fonts/Silkscreen-Regular.ttf',
  };

  for (final MapEntry<String, String> entry in fonts.entries) {
    final Uint8List bytes = await File(entry.value).readAsBytes();
    final FontLoader loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}
