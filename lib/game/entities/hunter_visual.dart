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
    this.bowGripYFraction = bowGripYFractionDefault,
    this.handHeightFraction = handHeightFractionDefault,
  });

  /// Default body height. The Phase 9A artwork is rendered significantly larger
  /// than the original prototype — approximately 2x the ORIGINAL procedural
  /// Hunter's visual height (~76), so the character reads as a proper size on a
  /// real phone. Aspect ratio is preserved (computed from the source image).
  static const double bodyHeightDefault = 200;

  /// Default bow height.
  static const double bowHeightDefault = 160;

  /// Default arrow length.
  static const double arrowLengthDefault = 170;

  /// Where the Hunter's hand grips the bow, as a fraction of the bow sprite's
  /// height measured from the TOP of the sprite. Placing the grip at this point
  /// aligns the bow grip with the front hand and keeps the (short) lower limb
  /// above the feet instead of hanging below them.
  static const double bowGripYFractionDefault = 0.74;

  /// How high the front hand sits above the feet, as a fraction of the Hunter
  /// body height. The old placeholder used a fixed -42px for a ~76px body; the
  /// enlarged Phase 9A artwork scales this proportionally so the hand (and the
  /// bow/arrow attached to it) sit at the correct height on a real phone.
  static const double handHeightFractionDefault = 0.55;

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

  /// Where the bow grip sits within the bow sprite (fraction of height from
  /// top). This is the pivot the bow rotates around at the Hunter's hand.
  final double bowGripYFraction;

  /// How high the front hand sits above the feet (fraction of body height).
  final double handHeightFraction;

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
