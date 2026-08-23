import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Guards against missing glyphs in the bundled pixel fonts.
///
/// This exists because of a real bug: `closureWindow` used '→' (U+2192), which
/// Silkscreen does not have, so every time range rendered as tofu — in both
/// languages. Pixel fonts have sparse coverage, and Google Fonts' declared
/// `unicode-range` is not proof that a glyph exists, so the only reliable
/// check is the font binary itself.
void main() {
  const List<String> fonts = <String>[
    'assets/fonts/PressStart2P-Regular.ttf',
    'assets/fonts/Silkscreen-Regular.ttf',
  ];

  /// Separators and glyphs composed in Dart rather than in the ARB files.
  const Set<String> literalsFromSource = <String>{'·', '-', ':', '%'};

  late Set<int> copyCodePoints;

  setUpAll(() {
    copyCodePoints = <int>{};
    for (final FileSystemEntity entity in Directory('lib/l10n').listSync()) {
      if (!entity.path.endsWith('.arb')) continue;
      final Map<String, dynamic> arb =
          jsonDecode(File(entity.path).readAsStringSync())
              as Map<String, dynamic>;
      arb.forEach((String key, dynamic value) {
        // '@'-prefixed keys are metadata, never shown to anyone.
        if (key.startsWith('@')) return;
        if (value is String) copyCodePoints.addAll(value.runes);
      });
    }
    for (final String literal in literalsFromSource) {
      copyCodePoints.addAll(literal.runes);
    }
    // ICU placeholders are substituted at runtime, so the braces never render.
    copyCodePoints.removeAll(<int>[0x7B, 0x7D]);
  });

  for (final String path in fonts) {
    test('${path.split('/').last} covers every character in the UI copy', () {
      final _Cmap cmap = _Cmap.parse(File(path).readAsBytesSync());

      final List<String> missing = <String>[];
      for (final int codePoint in copyCodePoints) {
        if (!cmap.covers(codePoint)) {
          missing.add(
            '${String.fromCharCode(codePoint)} '
            '(U+${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')})',
          );
        }
      }
      missing.sort();

      expect(
        missing,
        isEmpty,
        reason:
            'These characters appear in the UI copy but have no glyph in '
            '$path, so they will render as tofu:\n  ${missing.join('\n  ')}\n'
            'Either pick a character the font has, or bundle a font that '
            'covers it.',
      );
    });
  }

  test('the parser really can tell present from absent', () {
    // A self-check: if this ever passes trivially, the test above is useless.
    final _Cmap silkscreen = _Cmap.parse(
      File('assets/fonts/Silkscreen-Regular.ttf').readAsBytesSync(),
    );
    expect(silkscreen.covers(0x41), isTrue, reason: 'A must be present');
    expect(
      silkscreen.covers(0x2192),
      isFalse,
      reason: 'Silkscreen genuinely lacks the rightwards arrow',
    );
  });
}

/// Minimal TrueType `cmap` reader: enough to answer "is this codepoint
/// mapped to a real glyph?" for format 4 subtables.
class _Cmap {
  _Cmap._(this._segments);

  factory _Cmap.parse(Uint8List bytes) {
    final ByteData data = ByteData.sublistView(bytes);

    final int tableCount = data.getUint16(4);
    int? cmapOffset;
    for (int i = 0; i < tableCount; i++) {
      final int record = 12 + 16 * i;
      final String tag = String.fromCharCodes(bytes, record, record + 4);
      if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
    }
    if (cmapOffset == null) throw StateError('font has no cmap table');

    // Prefer a Unicode BMP/full subtable.
    const List<(int, int)> preferred = <(int, int)>[
      (3, 1),
      (3, 10),
      (0, 3),
      (0, 4),
      (0, 6),
    ];
    final int subtableCount = data.getUint16(cmapOffset + 2);
    int? best;
    for (int i = 0; i < subtableCount; i++) {
      final int record = cmapOffset + 4 + 8 * i;
      final (int platform, int encoding) = (
        data.getUint16(record),
        data.getUint16(record + 2),
      );
      if (preferred.contains((platform, encoding))) {
        best = cmapOffset + data.getUint32(record + 4);
      }
    }
    if (best == null) throw StateError('font has no Unicode cmap subtable');

    final int format = data.getUint16(best);
    if (format != 4) {
      throw StateError('unsupported cmap format $format; extend this parser');
    }

    final int segCountX2 = data.getUint16(best + 6);
    final int segCount = segCountX2 ~/ 2;
    final int endBase = best + 14;
    final int startBase = endBase + segCountX2 + 2;
    final int deltaBase = startBase + segCountX2;
    final int rangeBase = deltaBase + segCountX2;

    final List<_Segment> segments = <_Segment>[];
    for (int s = 0; s < segCount; s++) {
      segments.add(
        _Segment(
          start: data.getUint16(startBase + 2 * s),
          end: data.getUint16(endBase + 2 * s),
          idDelta: data.getInt16(deltaBase + 2 * s),
          idRangeOffset: data.getUint16(rangeBase + 2 * s),
          rangeFieldAddress: rangeBase + 2 * s,
          data: data,
        ),
      );
    }
    return _Cmap._(segments);
  }

  final List<_Segment> _segments;

  bool covers(int codePoint) {
    for (final _Segment segment in _segments) {
      if (codePoint < segment.start || codePoint > segment.end) continue;
      if (segment.start == 0xFFFF) continue;
      return segment.glyphFor(codePoint) != 0;
    }
    return false;
  }
}

class _Segment {
  const _Segment({
    required this.start,
    required this.end,
    required this.idDelta,
    required this.idRangeOffset,
    required this.rangeFieldAddress,
    required this.data,
  });

  final int start;
  final int end;
  final int idDelta;
  final int idRangeOffset;
  final int rangeFieldAddress;
  final ByteData data;

  int glyphFor(int codePoint) {
    if (idRangeOffset == 0) return (codePoint + idDelta) & 0xFFFF;
    final int address =
        rangeFieldAddress + idRangeOffset + 2 * (codePoint - start);
    final int glyph = data.getUint16(address);
    return glyph == 0 ? 0 : (glyph + idDelta) & 0xFFFF;
  }
}
