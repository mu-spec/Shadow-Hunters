import 'package:flame/components.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_hunters/game/aim/aim_state.dart';
import 'package:shadow_hunters/game/entities/hunter.dart';

void main() {
  // Hunter visual dimensions (feet anchored).
  const hunterW = 48.0;
  const hunterH = 76.0;
  final feet = Vector2(220, 600);

  Hunter makeHunter() => Hunter(position: feet, aim: AimState());

  group('Hunter.aimTouchRect (full-body touch rectangle)', () {
    test('covers head, torso, waist and legs of the visible body', () {
      final rect = makeHunter().aimTouchRect;
      final margin = Hunter.aimTouchMargin;

      // Head is near the top of the body (feet.y - height).
      expect(rect.contains(Offset(feet.x, feet.y - hunterH)), isTrue);
      // Chest/upper torso.
      expect(rect.contains(Offset(feet.x, feet.y - hunterH * 0.75)), isTrue);
      // Center torso.
      expect(rect.contains(Offset(feet.x, feet.y - hunterH * 0.5)), isTrue);
      // Waist.
      expect(rect.contains(Offset(feet.x, feet.y - hunterH * 0.3)), isTrue);
      // Legs (near the feet).
      expect(rect.contains(Offset(feet.x, feet.y)), isTrue);

      // The rect extends a margin above the head and below the feet.
      expect(rect.top, lessThanOrEqualTo(feet.y - hunterH));
      expect(rect.bottom, greaterThanOrEqualTo(feet.y));
      expect(rect.left, lessThanOrEqualTo(feet.x - hunterW / 2));
      expect(rect.right, greaterThanOrEqualTo(feet.x + hunterW / 2));
      // Sanity: margin is positive.
      expect(margin, greaterThan(0));
    });

    test('touch clearly outside the body does NOT start aim', () {
      final rect = makeHunter().aimTouchRect;
      // Far to the right and far above the head.
      expect(rect.contains(Offset(feet.x + 200, feet.y)), isFalse);
      expect(rect.contains(Offset(feet.x, feet.y - hunterH - 100)), isFalse);
    });

    test('touch area is centered on the full component, not the feet', () {
      final h = makeHunter();
      final rect = h.aimTouchRect;
      expect(rect.center.dx, closeTo(feet.x, 0.001));
      expect(rect.center.dy, closeTo(feet.y - hunterH / 2, 0.001));
      expect(rect.width, closeTo(h.size.x + Hunter.aimTouchMargin * 2, 0.001));
      expect(rect.height, closeTo(h.size.y + Hunter.aimTouchMargin * 2, 0.001));
    });

    test('rect follows the Hunter when he moves (camera-follow aware)', () {
      final h = makeHunter();
      h.position.x = 1500; // moved far right (camera would follow)
      final rect = h.aimTouchRect;
      // Body rect is still centered on the new position.
      expect(rect.center.dx, closeTo(1500, 0.001));
      expect(rect.contains(Offset(1500, feet.y - hunterH)), isTrue);
      expect(rect.contains(Offset(1500, feet.y)), isTrue);
    });
  });
}
