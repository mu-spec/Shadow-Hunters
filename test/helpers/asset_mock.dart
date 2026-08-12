import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';

/// Serves `assets/**` (level JSON, Hunter/Bow/Arrow PNGs, etc.) from disk
/// through the `flutter/assets` channel.
///
/// In `flutter test` the real [rootBundle] can't read declared assets through
/// the `flutter/assets` platform channel — it returns `null` by default, which
/// makes [PlatformAssetBundle.load] throw `Unable to load asset`. That error
/// escapes as unhandled async work and fails tests that run the full game's
/// `onLoad()`.
///
/// This mock decodes the (UTF-8 + URI-encoded) asset key exactly the way
/// `PlatformAssetBundle.load` encodes it, reads the matching file from disk,
/// and returns its bytes so both the level loader AND the Phase 9A sprite
/// loading (`rootBundle.load('assets/hunter.png')`) work in tests.
void mockLevelAssets(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final encoded = utf8.decode(message.buffer.asUint8List());
      final key = Uri.decodeFull(encoded);
      // Serve any bundled asset under assets/ that exists on disk.
      if (key.startsWith('assets/')) {
        final file = File(key);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          return ByteData.sublistView(bytes);
        }
      }
      return null; // fall through to the default (error) for anything else
    },
  );
}
