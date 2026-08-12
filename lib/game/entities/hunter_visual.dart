import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart' show Sprite;

/// Holds the Phase 9A Hunter artwork.
///
/// This milestone (9A-1) integrates only the Hunter BODY sprite. The Bow and
/// Arrow sprites will be added as their own separate milestones. The sprite is
/// rendered feet-aligned at the existing bottom-center anchor, scaled to ~2x
/// the original procedural Hunter's visual height while preserving aspect
/// ratio. Gameplay (hitbox, movement, aiming math, combat) is untouched.
class HunterVisual {
  const HunterVisual({
    required this.body,
    this.bodyHeight = bodyHeightDefault,
  });

  /// Default body height: ~2x the original procedural Hunter (~76px) so it
  /// reads at a proper size on a real phone while keeping the world readable.
  static const double bodyHeightDefault = 200;

  /// The Hunter body sprite (feet at the bottom of the image).
  final Sprite body;

  /// Desired on-screen body height (world px). Aspect ratio preserved.
  final double bodyHeight;

  /// Computed body width from the source aspect ratio.
  double bodyWidthFor(double height) {
    final img = body.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return h > 0 ? height * (w / h) : height;
  }

  /// Loads the Hunter body sprite through the game's image cache. Returns null
  /// if it fails to load, so the procedural fallback is preserved.
  static Future<HunterVisual?> load(Images images) async {
    try {
      // Flame's Images cache prepends a prefix (default "assets/images/"); our
      // asset lives at "assets/hunter.png", so clear the prefix.
      images.prefix = '';
      final body = await Sprite.load('assets/hunter.png', images: images);
      return HunterVisual(body: body);
    } catch (_) {
      return null;
    }
  }
}
