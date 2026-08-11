import 'dart:ui';

import 'package:flame/components.dart' show Vector2;

/// The battlefield world is wider than one screen so the camera must pan.
/// Its height fills the full screen height on every device (see the game's
/// camera zoom), so only the horizontal axis needs to pan.
const double worldWidth = 2560;
const double worldHeight = 720;

/// Ground band occupies the bottom of the world.
const double groundHeight = 120;
const double groundY = worldHeight - groundHeight; // top edge of the ground

/// Thickness of the boundary walls (shared by WorldBounds and movement clamps).
const double wallThickness = 14;

/// Player spawn point (feet position on the ground).
final Vector2 playerSpawn = Vector2(220, groundY);

/// Enemy spawn point (marker only until enemies are added).
final Vector2 enemySpawn = Vector2(worldWidth - 220, groundY);

// --- Hunter ---
const double hunterSpeed = 260; // px per second (frame-rate independent)
const double hunterHalfWidth = 22; // for boundary clamping
const int hunterMaxHealth = 100;

// Horizontal limits the hunter's center may travel to.
const double hunterBoundaryLeft = wallThickness + hunterHalfWidth;
const double hunterBoundaryRight = worldWidth - wallThickness - hunterHalfWidth;

// --- Bow / arrow combat ---
const double arrowMinSpeed = 420; // px/s at minimum power
const double arrowMaxSpeed = 1200; // px/s at full power
const double arrowGravity = 900; // px/s^2 downward
const double maxAimPull = 240; // drag distance (px) required for full power
const double bowLength = 44; // visual length of the bow
const double arrowLength = 46; // visual length of the arrow
const double bowMaxDraw = 18; // max bowstring draw-back (world units) at full power

// --- Skeleton (Milestone 2A) ---
const double skeletonSpeed = 72;
const double skeletonAttackRange = 42;
const double skeletonAttackCooldown = 1.0;
const double skeletonAttackDamage = 10;
const int skeletonBodyDamage = 10;
const int skeletonHeadDamage = 25;
const int skeletonMaxHealth = 40;
const double combatFeedbackDuration = 0.55;
const double skeletonHurtDuration = 0.16;
const double skeletonDeathDuration = 0.35;

// --- Zombie (Milestone 4A) ---
// A slow, tanky, hard-hitting melee enemy. It is a larger target than the
// Skeleton, deals stronger melee damage, attacks more slowly, and takes many
// more arrows to bring down — so it feels clearly distinct from the Skeleton.
const double zombieSpeed = 34; // slow
const double zombieAttackRange = 50;
const double zombieAttackCooldown = 1.9; // slow attack speed
const double zombieAttackDamage = 24; // strong melee attack
const int zombieBodyDamage = 12;
const int zombieHeadDamage = 30; // headshots supported
const int zombieMaxHealth = 160; // high health
const double zombieHurtDuration = 0.18;
const double zombieDeathDuration = 0.45;

// --- Goblin (Milestone 5A) ---
// A fast, fragile melee enemy: it is a smaller target, has low health, hits
// quickly with light damage, and occasionally performs a short, telegraphed
// dodge hop. It reuses the shared Enemy combat pipeline.
const double goblinSpeed = 150; // fast movement
const double goblinAttackRange = 38;
const double goblinAttackCooldown = 0.55; // fast melee attack
const double goblinAttackDamage = 8; // light
const int goblinBodyDamage = 7;
const int goblinHeadDamage = 20; // headshots supported
const int goblinMaxHealth = 25; // low health
const double goblinHurtDuration = 0.14;
const double goblinDeathDuration = 0.3;

// Goblin dodge: cooldown-gated, telegraphed, predictable, boundary-safe.
const double goblinDodgeCooldown = 3.0; // cannot dodge again for this long
const double goblinDodgeDistance = 70; // short hop
const double goblinDodgeSpeed = 320; // quick hop
const double goblinDodgeTelegraphDuration = 0.3; // windup before the hop
const double goblinDodgeIntervalMin = 1.5; // occasional
const double goblinDodgeIntervalMax = 3.0;

/// Colors shared by the prototype battlefield.
const Color skyTop = Color(0xFF4A6E8C);
const Color skyBottom = Color(0xFF7FA3B8);
const Color treeSilhouette = Color(0xFF3A6B45);
const Color groundGrass = Color(0xFF5E9A44);
const Color groundDirt = Color(0xFF8A5A32);
const Color wallColor = Color(0x3300FF00); // faint green boundary outline
