import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart' show Sprite;

/// Holder for the Phase 9A static Hunter + Bow + Arrow artwork.
///
/// This is a CONTROLLED VISUAL PROTOTYPE: it swaps the procedural placeholder
/// Hunter visuals for the supplied PNG art. Gameplay (movement, aiming math,
/// hitbox, arrows, damage, etc.) is untouched. Each sprite is drawn separately
/// and scaled to approximately 2x the placeholder Hunter's visual height while
/// preserving aspect ratio. Sizes/offsets below are the integration constants
/// and can be tuned without touching gameplay.
class HunterVisual {
  const HunterVisual({
    required this.body,
    required this.bow,
    required this.arrow,
    this.bodyHeight = bodyHeightDefault,
    this.bowHeight = bowHeightDefault,
    this.arrowLength = arrowLengthDefault,
  });

  /// Default body height (~2x the placeholder Hunter height of 76).
  static const double bodyHeightDefault = 152;

  /// Default bow height.
  static const double bowHeightDefault = 150;

  /// Default arrow length.
  static const double arrowLengthDefault = 150;

  /// Hunter body sprite.
  final Sprite body;

  /// Bow sprite (drawn separately from the body, rotated to aim).
  final Sprite bow;

  /// Arrow sprite (used for the nocked bow arrow and the flying projectile).
  final Sprite arrow;

  /// Desired on-screen body height (world px). Aspect preserved.
  final double bodyHeight;

  /// Desired on-screen bow height (world px). Aspect preserved.
  final double bowHeight;

  /// Desired on-screen nocked/fired arrow length (world px). Aspect preserved.
  final double arrowLength;

  /// Computed body width from its source aspect ratio.
  double bodyWidthFor(double height) {
    final img = body.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return h > 0 ? height * (w / h) : height;
  }

  /// Computed bow width from its source aspect ratio.
  double bowWidthFor(double height) {
    final img = bow.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return h > 0 ? height * (w / h) : height;
  }

  /// Computed arrow height from its source aspect ratio.
  double arrowHeightFor(double length) {
    final img = arrow.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return w > 0 ? length * (h / w) : length;
  }

  /// Loads the three Phase 9A sprites through the game's image cache. Returns
  /// null if any asset fails to load, so callers can keep the procedural
  /// fallback path.
  static Future<HunterVisual?> load(Images images) async {
    try {
      // Flame's Images cache prepends a prefix (default "assets/images/"). Our
      // assets live at the project root under "assets/" and we pass the full
      // path, so clear the prefix to avoid "assets/images/assets/hunter.png".
      images.prefix = '';
      final body = await Sprite.load('assets/hunter.png', images: images);
      final bow = await Sprite.load('assets/bow.png', images: images);
      final arrow = await Sprite.load('assets/arrow.png', images: images);
      return HunterVisual(body: body, bow: bow, arrow: arrow);
    } catch (_) {
      return null;
    }
  }
}
