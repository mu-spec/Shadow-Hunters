import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart' show Sprite;

/// Holds the Phase 9A Hunter artwork.
///
/// This milestone (9A-2) integrates the BODY sprite (9A-1) plus the BOW sprite.
/// The bow is rendered in the artwork path, aligned so its grip/riser sits on
/// the same pivot the gameplay uses for the arrow launch origin, keeping the
/// fired arrow visually continuous with the bow. The bow's draw-tension string
/// and nocked arrow stay procedural (arrow art is a later milestone). Gameplay
/// (hitbox, movement, aiming math, combat) is untouched.
class HunterVisual {
  const HunterVisual({
    required this.body,
    this.bow,
    this.bodyHeight = bodyHeightDefault,
    this.bowHeight = bowHeightDefault,
  });

  /// Default body height: ~2x the original procedural Hunter (~76px) so it
  /// reads at a proper size on a real phone while keeping the world readable.
  static const double bodyHeightDefault = 200;

  /// Default bow height. Chosen so that, with the grip pivot fixed at the
  /// gameplay launch height (local y=-42), the bottom limb rests on the ground
  /// and the top limb stays below the Hunter's head.
  static const double bowHeightDefault = 100;

  /// Fraction of the bow sprite's height (measured from the top) where its
  /// grip/riser is located. This is where the archer's hand holds the bow, so
  /// the artwork is positioned to put this point exactly on the launch pivot.
  static const double bowGripYFraction = 0.58;

  /// The Hunter body sprite (feet at the bottom of the image).
  final Sprite body;

  /// The bow sprite, oriented vertically with its belly toward +x. When null,
  /// the procedural bow arc is used as a fallback.
  final Sprite? bow;

  /// Desired on-screen body height (world px). Aspect ratio preserved.
  final double bodyHeight;

  /// Desired on-screen bow height (world px). Aspect ratio preserved.
  final double bowHeight;

  /// Computed body width from the source aspect ratio.
  double bodyWidthFor(double height) {
    final img = body.image;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return h > 0 ? height * (w / h) : height;
  }

  /// Computed bow width from the source aspect ratio.
  double bowWidthFor(double height) {
    final img = bow?.image;
    if (img == null) return 0;
    final w = img.width.toDouble();
    final h = img.height.toDouble();
    return h > 0 ? height * (w / h) : height;
  }

  /// Loads the Hunter body and bow sprites through the game's image cache.
  /// Returns null if the body fails to load (procedural fallback). The bow is
  /// optional: if it fails, only the procedural arc is used.
  static Future<HunterVisual?> load(Images images) async {
    try {
      // Flame's Images cache prepends a prefix (default "assets/images/"); our
      // assets live at "assets/...", so clear the prefix.
      images.prefix = '';
      final body = await Sprite.load('assets/hunter.png', images: images);
      Sprite? bow;
      try {
        bow = await Sprite.load('assets/bow.png', images: images);
      } catch (_) {
        bow = null;
      }
      return HunterVisual(body: body, bow: bow);
    } catch (_) {
      return null;
    }
  }
}
