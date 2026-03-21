# Pixi Dragon — Technical Documentation

> Platform: Android | Framework: Flutter | State: Provider | Storage: shared_preferences | Audio: audioplayers

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Coordinate System](#3-coordinate-system)
4. [Game States](#4-game-states)
5. [GameProvider](#5-gameprovider)
6. [Physics Engine](#6-physics-engine)
7. [Pipe System](#7-pipe-system)
8. [Collision Detection](#8-collision-detection)
9. [Scoring System](#9-scoring-system)
10. [AudioService](#10-audioservice)
11. [Screens](#11-screens)
12. [Widgets](#12-widgets)
13. [Local Persistence](#13-local-persistence)
14. [Tuning Reference](#14-tuning-reference)
15. [Known Limitations](#15-known-limitations)
16. [How to Extend](#16-how-to-extend)

---

## 1. Project Overview

Pixi Dragon is a Flappy Bird-style arcade game for Android built entirely in Flutter. The player taps the screen to make a dragon flap upward against gravity. The dragon must fly through gaps between pairs of pipes moving from right to left. The game ends on any collision. Best score is saved permanently on the device.

There is no backend, no internet requirement, and no authentication. Everything runs and stores locally on the Android device.

---

## 2. Architecture

```
lib/
 ├── constants/
 │    └── app_assets.dart         — asset path constants
 ├── providers/
 │    └── game_provider.dart      — entire game logic and state
 ├── screens/
 │    ├── splash_screen.dart      — launch screen
 │    ├── game_screen.dart        — main game UI
 │    └── settings_screen.dart    — audio settings
 ├── services/
 │    └── audio_service.dart      — music playback and volume
 ├── widgets/
 │    ├── dragon.dart             — dragon sprite widget
 │    ├── pipe.dart               — pipe pair widget
 │    └── score_bar.dart          — score display widget
 └── main.dart                   — app entry point, providers
```

### Dependency graph

```
main.dart
  └── MultiProvider
       ├── AudioService   (ChangeNotifier)
       └── GameProvider   (ChangeNotifier)
            └── GameScreen
                 ├── Dragon
                 ├── Pipe (×2)
                 ├── ScoreBar
                 └── SettingsScreen
                      └── AudioService
```

### Why Provider over other state management?

Provider was chosen because the game has a single source of truth (`GameProvider`) that many widgets read from simultaneously. The 16ms game loop calls `notifyListeners()` every tick, which efficiently rebuilds only the widgets that called `context.watch<GameProvider>()`. No unnecessary global rebuilds.

---

## 3. Coordinate System

All game logic uses a **normalized coordinate system** where:

```
x:  -1.0 = left edge of screen    +1.0 = right edge of screen
y:  -1.0 = top edge of screen     +1.0 = bottom edge of screen
     0.0 = horizontal/vertical centre
```

### Why normalized instead of pixels?

Using pixels directly causes collision boxes to break across different screen sizes. A pipe gap of 200px feels large on a small phone but tiny on a tablet. Normalized units are proportional — `0.32` of the screen height is `0.32` everywhere regardless of device.

### Converting normalized → pixels (used in pipe.dart)

```dart
// Normalized x to pixel x
final pixelX = (normX + 1) / 2 * screenWidth;

// Normalized y to pixel y
final pixelY = (normY + 1) / 2 * screenHeight;
```

### Screen size injection

`GameProvider` stores `_screenSize` and exposes `updateScreenSize(Size size)`. `GameScreen` calls this every frame via `addPostFrameCallback` so geometry derived from screen size (ground top, dragon half-height, pipe half-width) is always accurate for the current device.

```dart
// In game_screen.dart — called every build
WidgetsBinding.instance.addPostFrameCallback((_) {
  context.read<GameProvider>().updateScreenSize(
    MediaQuery.of(context).size,
  );
});
```

---

## 4. Game States

`GameProvider` uses an enum to manage the three states of the game:

```dart
enum GameState { ready, playing, gameOver }
```

| State | Description | What is visible |
|---|---|---|
| `ready` | App just launched or restart pressed | Dragon, START button, settings icon, score bar |
| `playing` | Game loop running | Dragon, pipes, score bar, tap layer |
| `gameOver` | Collision occurred, loop stopped | Game Over card, score, best, RESTART button |

### State transitions

```
ready ──[START pressed]──▶ playing
playing ──[collision]────▶ gameOver
gameOver ──[RESTART]─────▶ ready
```

RESTART calls `game.reset()` which clears all pipe data and returns to `ready`. It does NOT restart music — music runs continuously throughout.

---

## 5. GameProvider

**File:** `lib/providers/game_provider.dart`

`GameProvider` is the core of the entire game. It extends `ChangeNotifier` and owns:
- Dragon position and velocity
- All pipe positions and gap data
- Score and best score
- The 16ms game loop timer
- Collision detection
- Persistence of best score

### Public API

| Method | Description |
|---|---|
| `startGame()` | Transitions ready → playing, initialises pipes, starts loop |
| `flap()` | Applies upward jump velocity to dragon |
| `reset()` | Stops loop, clears all state, returns to ready |
| `updateScreenSize(Size)` | Injects screen dimensions for geometry calculations |

### Key getters

| Getter | Type | Description |
|---|---|---|
| `state` | `GameState` | Current game state |
| `dragonY` | `double` | Dragon vertical position (normalized) |
| `pipeX` | `List<double>` | Pipe centre X positions (normalized) |
| `pipeGapY` | `List<double>` | Pipe gap centre Y positions (normalized) |
| `score` | `int` | Current game score |
| `bestScore` | `int` | All-time best score (loaded from device) |

---

## 6. Physics Engine

The physics runs inside `_tick()`, called every 16 milliseconds by a `Timer.periodic`.

### Delta time (dt)

```dart
final dt = (now.difference(_lastTick!).inMicroseconds / 1e6).clamp(0.0, 0.05);
```

`dt` is the time elapsed since the last tick in seconds (typically ~0.016). It is clamped to `0.05` to prevent the dragon jumping a huge distance if the app freezes for a frame (e.g. during a garbage collection pause).

### Gravity and velocity

```dart
void _updateDragon(double dt) {
  _velocity += _gravity * dt;   // velocity increases downward each tick
  _dragonY  += _velocity * dt;  // position moves by velocity each tick
}
```

This is standard **Euler integration** — simple, fast, and sufficient for this type of game. The dragon accelerates downward naturally and the player counters it with flaps.

### Flap

```dart
void flap() {
  _velocity = _jumpVelocity; // -1.4 — instantly set to upward velocity
}
```

Flap does not add to velocity — it replaces it. This means spamming taps doesn't cause the dragon to rocket upward; each tap gives the same jump regardless of current velocity.

### Physics constants

| Constant | Value | Effect |
|---|---|---|
| `_gravity` | `3.8` | Downward acceleration per second |
| `_jumpVelocity` | `-1.4` | Upward velocity on tap (negative = up) |

---

## 7. Pipe System

### Pool design

Two pipes are kept in memory at all times in three parallel lists:

```dart
final List<double> _pipeX      = [];  // centre X of each pipe
final List<double> _pipeGapY   = [];  // gap centre Y of each pipe
final List<bool>   _pipeScored = [];  // whether this pipe has been scored
```

When a pipe moves past the left edge (`_pipeRecycleX = -1.4`), it is not destroyed — it is **repositioned** to after the furthest pipe with a new random gap. This avoids creating and destroying objects during gameplay.

### Recycling logic

```dart
if (_pipeX[i] < _pipeRecycleX) {
  final maxX    = _pipeX.reduce(max);   // find the leading pipe
  final randomSep = 1.6 + Random().nextDouble() * 0.6; // 1.6 to 2.2
  _pipeX[i]      = maxX + randomSep;   // place behind it
  _pipeGapY[i]   = _randomGapY();      // new random gap position
  _pipeScored[i] = false;              // reset score flag
}
```

### Random separation

The distance between pipes is randomised between `1.6` and `2.2` normalized units each time a pipe is recycled. This prevents the player learning a fixed rhythm.

### Gap randomisation

```dart
double _randomGapY() {
  const min = -0.25;
  const max =  0.25;
  return min + Random().nextDouble() * (max - min);
}
```

The gap centre is kept between `-0.25` and `+0.25` (centre 25% of screen) so the full gap opening is always fully visible and never cut off by the ground or ceiling.

### Speed and difficulty

```dart
final speed = _score >= 10 ? _fastPipeSpeed : _basePipeSpeed;
```

At score 10 the pipes permanently increase speed. There is one difficulty jump, not a gradual curve. This was a deliberate design choice for a sharp, noticeable difficulty increase.

---

## 8. Collision Detection

**All collision checks run in normalized `-1.0 to +1.0` space.**

### Dragon AABB

The dragon's axis-aligned bounding box is computed each tick:

```dart
final dHalfH = _dragonHalfH;          // visible body height / 2
final dTop    = _dragonY - dHalfH;    // top edge
final dBottom = _dragonY + dHalfH;    // bottom edge
final dHalfW  = dHalfH * 0.70;        // width is 70% of height
final dLeft   = -dHalfW;
final dRight  =  dHalfW;
```

### Why body fractions?

Every image asset has transparent padding around the visible sprite. Using the full image dimensions as hitbox bounds makes the dragon die before it visually touches anything. The body fractions shrink the hitbox to match only the visible pixels:

```dart
// Dragon: 85px image, 45% is visible body = 38.25px hitbox height
double get _dragonHalfH {
  return (_dragonImagePx * _dragonBodyFraction) / (_screenSize.height / 2);
}

// Pipe: 80px image, 65% is visible column = 52px hitbox width
double get _pipeHalfW {
  return (pipeWidthPx * _pipeBodyFraction) / 2.0 / (_screenSize.width / 2.0);
}
```

### Collision checks (in order)

**1. Ceiling**
```dart
if (dTop <= -1.0) { _triggerGameOver(); return; }
```

**2. Ground**
```dart
if (dBottom >= _groundTopNorm) { _triggerGameOver(); return; }
```

`_groundTopNorm` is the normalized Y of the visible brick surface, not the image top. The ground image has transparent area at the top, so collision is calculated from `50%` into the image:

```dart
double get _groundTopNorm {
  final visibleFromBottom = _groundImageHeightPx * (1.0 - _groundSurfaceFraction);
  final brickTopPx = _screenSize.height - visibleFromBottom;
  return (brickTopPx / (_screenSize.height / 2)) - 1.0;
}
```

**3. Pipes**
```dart
// Step 1: check horizontal overlap
if (dRight <= pLeft || dLeft >= pRight) continue; // no overlap, skip

// Step 2: check vertical position
final gapTop    = _pipeGapY[i] - gapHalfHeight;
final gapBottom = _pipeGapY[i] + gapHalfHeight;

// Dragon must be FULLY inside gap to survive
if (dTop < gapTop || dBottom > gapBottom) {
  _triggerGameOver();
}
```

The dragon is only safe when horizontally overlapping a pipe if **both** its top and bottom edges are within the gap corridor. Any single edge outside = game over.

---

## 9. Scoring System

A pipe is scored exactly once when its right edge passes the dragon centre (x = 0):

```dart
if (!_pipeScored[i] && (_pipeX[i] + _pipeHalfW) < 0.0) {
  _pipeScored[i] = true;
  _score++;
  if (_score > _bestScore) {
    _bestScore = _score;
    _saveBestScore(); // write to device immediately
  }
}
```

`_pipeScored[i]` prevents the same pipe awarding multiple points as it continues moving left.

Best score is written to `shared_preferences` the instant a new record is set — not on game over. This means even if the app crashes during a game, the best score up to that point is preserved.

---

## 10. AudioService

**File:** `lib/services/audio_service.dart`

`AudioService` is a `ChangeNotifier` that owns a single `AudioPlayer` instance from the `audioplayers` package.

### Why is it a ChangeNotifier?

The settings screen needs to react to volume and mute changes in real time (slider position, toggle state, percentage label). Making it a `ChangeNotifier` and providing it above `GameProvider` in `main.dart` means any widget can `context.watch<AudioService>()` and rebuild when settings change.

### Lifecycle

| Event | Action |
|---|---|
| App launches | `AudioService` initialises, loads saved settings, does NOT play |
| `GameScreen` mounts (splash ends) | `startMusic()` called via `initState` |
| App closed / screen disposed | `stopMusic()` called via `dispose` |
| User mutes | Volume set to 0.0, player continues running silently |
| User unmutes | Volume restored; if player stopped, `play()` called again |

### Why start music in GameScreen not in AudioService constructor?

If music started in the constructor, it would play during the splash screen. The requirement is that music starts exactly when the game screen appears. `GameScreen.initState()` is the correct hook for this — it fires once when the widget enters the tree, which is exactly when the splash fade completes.

### Persistence keys

| Key | Type | Default |
|---|---|---|
| `pixi_dragon_volume` | `double` | `0.7` |
| `pixi_dragon_muted` | `bool` | `false` |

---

## 11. Screens

### SplashScreen (`splash_screen.dart`)

- `StatefulWidget` with `SingleTickerProviderStateMixin`
- `AnimationController` fades in dragon + "ASK" text over 600ms
- After 2400ms, navigates to `GameScreen` using `PageRouteBuilder` with `FadeTransition` (700ms)
- Uses `pushReplacement` so back button does not return to splash

### GameScreen (`game_screen.dart`)

- `StatefulWidget` (needs `initState`/`dispose` for audio lifecycle)
- All three game states rendered in a single `Stack`
- Layers from bottom to top:
    1. Background image
    2. Pipes (playing only)
    3. Ground image
    4. Dragon
    5. Score bar (always)
    6. Settings icon (ready only)
    7. START button (ready only)
    8. Game Over card (gameOver only)
    9. Tap-to-flap GestureDetector (playing only)
- Settings navigation uses `SlideTransition` from right with `easeOutCubic`

### SettingsScreen (`settings_screen.dart`)

- `StatelessWidget` — reads `AudioService` via `context.watch`
- Dark themed (`#1A1A2E` background, `#16213E` card)
- Animated toggle switch (pill style, purple = on, grey = off)
- `Slider` widget with custom `SliderTheme`
- Slider is `null`-callback disabled when muted (greyed out automatically)
- No back button logic needed — uses default `AppBar` back arrow

---

## 12. Widgets

### Dragon (`dragon.dart`)

```dart
Align(
  alignment: Alignment(0, y),  // x=0 always centred, y from GameProvider
  child: Image.asset(AppAssets.dragon, width: 85, fit: BoxFit.contain),
)
```

`Alignment(0, y)` maps directly to the normalized coordinate system. `y = -1.0` is top, `y = 1.0` is bottom, matching `GameProvider.dragonY` exactly. No conversion needed.

### Pipe (`pipe.dart`)

Converts normalized coords to pixels for rendering:

```dart
// Pipe left edge in pixels (x is centre, subtract half-width)
final pipeLeftPx = (x + 1) / 2 * size.width - GameProvider.pipeWidthPx / 2;

// Gap centre in pixels
final gapCenterPx = (gapY + 1) / 2 * size.height;
```

Top pipe is flipped using `Matrix4.rotationX(pi)` so the pipe cap faces downward. Both pipes are rendered in a `Stack` of `Positioned` widgets.

### ScoreBar (`score_bar.dart`)

Uses a `Row` layout:
- Left: `BEST` label + value (padded 16px from left edge)
- Centre: `SCORE` label + value (inside `Expanded` + `Center`)
- Right: invisible `SizedBox(width: 80)` to mirror left column width and keep centre mathematically true

Always rendered — visible in all three game states.

---

## 13. Local Persistence

All data is stored using `shared_preferences` which writes to Android's `SharedPreferences` (XML file in the app's private storage). Data survives app restarts and device reboots. It is cleared when the app is uninstalled.

| Key | Written when | Read when |
|---|---|---|
| `pixi_dragon_best_score` | New best score achieved | `GameProvider` constructor |
| `pixi_dragon_volume` | User moves volume slider | `AudioService` constructor |
| `pixi_dragon_muted` | User taps mute toggle | `AudioService` constructor |

All writes are `async` fire-and-forget. The UI does not wait for the write to complete before updating — state updates immediately, disk write happens in background.

---

## 14. Tuning Reference

All gameplay feel is controlled by constants at the top of `game_provider.dart`. No other file needs to change for gameplay tuning.

| Constant | Current | Effect of increasing | Effect of decreasing |
|---|---|---|---|
| `gapHalfHeight` | `0.32` | Wider gap, easier | Narrower gap, harder |
| `_dragonBodyFraction` | `0.45` | Larger hitbox, dies sooner | Smaller hitbox, more forgiving |
| `_pipeBodyFraction` | `0.65` | Wider pipe hitbox | Narrower, less invisible wall |
| `_gravity` | `3.8` | Falls faster | Falls slower |
| `_jumpVelocity` | `-1.4` | Higher jump (more negative) | Lower jump |
| `_basePipeSpeed` | `0.9` | Faster pipes early | Slower pipes early |
| `_fastPipeSpeed` | `1.4` | Faster pipes after score 10 | Slower after spike |
| `_groundSurfaceFraction` | `0.50` | Collision higher on ground | Collision lower |
| `_pipeSeparation` | `1.8` | More space at spawn | Less space at spawn |
| `dHalfW multiplier` | `0.70` | Wider horizontal hitbox | Slimmer, easier side pass |

---

## 15. Known Limitations

**Pipe cap collision**
The pipe asset has a wider decorative cap at the opening end. The collision system treats the pipe as a uniform rectangle. The cap appears wider than the collision box horizontally and the gap edge does not account for the cap's extra height. Reducing `_pipeBodyFraction` and adjusting `gapHalfHeight` mitigates this but does not fully solve it without switching to a multi-rectangle hitbox per pipe.

**Single difficulty spike**
Difficulty only increases once at score 10. There is no further progression. To add more levels, implement a speed ramp based on score ranges instead of a single threshold.

**No pause**
There is no pause functionality. Pressing the Android back button during gameplay does not pause the game — the loop continues running.

**Audio format**
The audio file is `.mpeg`. If the file fails to load on certain devices, convert it to `.mp3` and update the asset path in `audio_service.dart` and `pubspec.yaml`.

---

## 16. How to Extend

### Add a new difficulty level

In `_updatePipes()` in `game_provider.dart`:
```dart
// Replace the single threshold with multiple ranges
double get _currentSpeed {
  if (_score >= 20) return 1.8;
  if (_score >= 10) return 1.4;
  return 0.9;
}
```

### Add a sound effect on flap or collision

In `audio_service.dart`, add a second `AudioPlayer` for sound effects:
```dart
final AudioPlayer _sfxPlayer = AudioPlayer();

Future<void> playFlap() async {
  await _sfxPlayer.play(AssetSource('audio/flap.mp3'));
}
```

Call `context.read<AudioService>().playFlap()` inside `GameProvider.flap()`.

### Add a high score screen

Create `lib/screens/highscore_screen.dart`. Read `pixi_dragon_best_score` from `shared_preferences` and display it. No changes to `GameProvider` needed.

### Change the dragon asset

Replace `assets/images/bird/flappy_dragon.png` with a new image of the same filename. If the new image has different transparent padding proportions, retune `_dragonBodyFraction` in `game_provider.dart`.

---

*Pixi Dragon — built with Flutter. All rights reserved.*