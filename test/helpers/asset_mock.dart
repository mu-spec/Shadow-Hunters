import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';

/// Serves `assets/levels/*.json` from disk through the `flutter/assets` channel.
///
/// In `flutter test` the real [rootBundle] can't read declared assets through
/// the `flutter/assets` platform channel — it returns `null` by default, which
/// makes [PlatformAssetBundle.load] throw `Unable to load asset`. That error
/// escapes as unhandled async work and fails tests that run the full game's
/// `onLoad()`.
///
/// This mock decodes the (UTF-8 + URI-encoded) asset key exactly the way
/// `PlatformAssetBundle.load` encodes it, reads the matching JSON from disk,
/// and returns its bytes so the game can load cleanly.
void mockLevelAssets(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final encoded = utf8.decode(message.buffer.asUint8List());
      final key = Uri.decodeFull(encoded);
      if (key.startsWith('assets/levels/') && key.endsWith('.json')) {
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
