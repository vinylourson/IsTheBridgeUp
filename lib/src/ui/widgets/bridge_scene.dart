import 'package:flutter/widgets.dart';

import '../theme/palette.dart';
import '../theme/pixel_sprites.dart';
import 'pixel_sprite.dart';

/// Layout of the scene, in sprite pixels. Everything scales from these, so the
/// composition holds together at any widget size.
class _Layout {
  const _Layout._();

  static const int width = 150;
  static const int height = 76;

  static const int towerTop = 3;
  static const int deckY = 48;
  static const int waterY = 56;
  static const int beamY = towerTop + 10;

  static const int leftTowerX0 = 34;
  static const int leftTowerX1 = 40;
  static const int rightTowerX0 = 104;
  static const int rightTowerX1 = 110;

  static const int spanX0 = 41;
  static const int spanX1 = 103;
  static const int spanHeight = 5;

  /// How high the lift span travels when fully raised.
  static const int spanRaisedY = beamY + 4;

  static const double aspectRatio = width / height;

  static const List<Offset> stars = <Offset>[
    Offset(12, 6),
    Offset(28, 14),
    Offset(52, 9),
    Offset(66, 5),
    Offset(88, 11),
    Offset(126, 7),
    Offset(140, 18),
  ];
}

/// Something crossing the bridge: its animation frames, how fast it moves,
/// where in the loop it starts, which way it faces, and where it sits when
/// motion is reduced.
class _Traveller {
  const _Traveller(
    this.frames,
    this.speed,
    this.phase,
    this.flip,
    this.restingX,
    this.frameEvery,
  );

  final List<List<String>> frames;
  final double speed;
  final double phase;
  final bool flip;
  final double restingX;

  /// Sprite pixels of travel per animation frame. A crank or a wheel turns
  /// faster than a stride, so this is set per traveller rather than shared.
  final int frameEvery;
}

/// The Chaban-Delmas bridge as a pixel-art scene: two lift towers, a span that
/// rises, water below, and either traffic crossing or a ship passing under.
class BridgeScene extends StatefulWidget {
  const BridgeScene({
    super.key,
    required this.raised,
    this.maintenance = false,
    this.animate = true,
  });

  /// True when the bridge is closed to traffic and the span is up.
  final bool raised;

  /// Maintenance closures get cones on the approach rather than a ship.
  final bool maintenance;

  final bool animate;

  @override
  State<BridgeScene> createState() => _BridgeSceneState();
}

class _BridgeSceneState extends State<BridgeScene>
    with TickerProviderStateMixin {
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: widget.raised ? 1 : 0,
  );

  /// One continuous loop drives both the drifting ship and the traffic.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimations();
  }

  @override
  void didUpdateWidget(BridgeScene old) {
    super.didUpdateWidget(old);
    if (old.raised != widget.raised || old.animate != widget.animate) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (!widget.animate) {
      _drift.stop();
      _lift.value = widget.raised ? 1 : 0;
      return;
    }
    if (widget.raised) {
      _lift.forward();
    } else {
      _lift.reverse();
    }
    if (!_drift.isAnimating) _drift.repeat();
  }

  @override
  void dispose() {
    _lift.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the platform's reduced-motion setting.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final bool animate = widget.animate && !reduceMotion;
    if (reduceMotion && _drift.isAnimating) _drift.stop();

    return AspectRatio(
      aspectRatio: _Layout.aspectRatio,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_lift, _drift]),
          builder: (BuildContext context, _) => CustomPaint(
            painter: _BridgeScenePainter(
              lift: Curves.easeInOut.transform(_lift.value),
              drift: _drift.value,
              animate: animate,
              maintenance: widget.maintenance,
            ),
          ),
        ),
      ),
    );
  }
}

class _BridgeScenePainter extends CustomPainter {
  const _BridgeScenePainter({
    required this.lift,
    required this.drift,
    required this.animate,
    required this.maintenance,
  });

  final double lift;
  final double drift;

  /// When false (reduced motion), everything is laid out in a fixed,
  /// deliberately composed frame instead of wherever the loop happened to be.
  final bool animate;
  final bool maintenance;

  @override
  void paint(Canvas canvas, Size size) {
    final double px = size.width / _Layout.width;
    final Paint paint = Paint()..isAntiAlias = false;

    void box(num x0, num y0, num x1, num y1, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTRB(
          x0 * px,
          y0 * px,
          (x1 + 1) * px,
          (y1 + 1) * px,
        ),
        paint,
      );
    }

    // Sky.
    box(0, 0, _Layout.width - 1, _Layout.height - 1, PixelPalette.background);
    for (final Offset star in _Layout.stars) {
      box(star.dx, star.dy, star.dx, star.dy, C64.darkGrey);
    }

    // Water, tiled.
    final PixelMatrix water = PixelMatrix.of(PixelSprites.water);
    for (int y = _Layout.waterY; y < _Layout.height; y += water.height) {
      for (int x = 0; x < _Layout.width; x += water.width) {
        water.paint(canvas, Offset(x * px, y * px), px);
      }
    }

    // Far half of the ship: it arrives on the other side of the bridge.
    _paintShip(canvas, px, size, near: false);

    // Approach decks on both banks.
    for (final (num a, num b) in <(num, num)>[
      (0, _Layout.leftTowerX0 - 1),
      (_Layout.rightTowerX1 + 1, _Layout.width - 1),
    ]) {
      box(a, _Layout.deckY, b, _Layout.deckY + 3, C64.black);
      box(a, _Layout.deckY + 1, b, _Layout.deckY + 2, PixelPalette.panelBorder);
      box(a, _Layout.deckY + 1, b, _Layout.deckY + 1, PixelPalette.structure);
    }

    // Piers and towers.
    for (final (int x0, int x1) in <(int, int)>[
      (_Layout.leftTowerX0, _Layout.leftTowerX1),
      (_Layout.rightTowerX0, _Layout.rightTowerX1),
    ]) {
      box(x0, _Layout.deckY, x1, _Layout.height - 1, C64.black);
      box(x0 + 1, _Layout.deckY, x1 - 1, _Layout.height - 1, PixelPalette.pier);

      box(x0, _Layout.towerTop, x1, _Layout.deckY, C64.black);
      box(
        x0 + 1,
        _Layout.towerTop + 1,
        x1 - 1,
        _Layout.deckY - 1,
        PixelPalette.structure,
      );
      box(
        x0 + 2,
        _Layout.towerTop + 2,
        x1 - 2,
        _Layout.deckY - 1,
        PixelPalette.structureBright,
      );
      // Crossbeam near the top, the bridge's most recognisable detail.
      box(x0 - 1, _Layout.beamY, x1 + 1, _Layout.beamY + 2, C64.black);
      box(x0, _Layout.beamY + 1, x1, _Layout.beamY + 1, PixelPalette.structure);
    }

    // Lift span, hanging from the towers.
    final double spanY =
        _Layout.deckY + (_Layout.spanRaisedY - _Layout.deckY) * lift;
    for (final int cableX in <int>[
      _Layout.leftTowerX0 + 3,
      _Layout.rightTowerX0 + 3,
    ]) {
      box(cableX, _Layout.towerTop + 2, cableX, spanY, PixelPalette.structure);
    }
    box(_Layout.spanX0, spanY, _Layout.spanX1, spanY + _Layout.spanHeight - 1,
        C64.black);
    box(_Layout.spanX0 + 1, spanY + 1, _Layout.spanX1 - 1,
        spanY + _Layout.spanHeight - 2, PixelPalette.panelBorder);
    box(_Layout.spanX0 + 1, spanY + 2, _Layout.spanX1 - 1, spanY + 2,
        PixelPalette.structure);

    // Centre line, only readable while the span is down.
    if (lift < 0.05) {
      for (int x = _Layout.spanX0 + 4; x < _Layout.spanX1 - 3; x += 7) {
        box(x, spanY + 2, x + 2, spanY + 2, PixelPalette.roadLine);
      }
    }

    // Sodium deck lighting, implied rather than built: a lamp standard is
    // about 8 m, which is 68 px at this scale and taller than the whole
    // scene. Drawing the posts made a picket fence, so instead there are
    // pools of warm light on the deck and a dim smear on the water.
    for (int x = 8; x < _Layout.width; x += 19) {
      // Lamps over the lift span ride up with it: they are fixed to the deck
      // that moves. Held at deck level they hung in mid-air over the open
      // channel, which is exactly what a raised span leaves behind.
      //
      // Drawn on the road surface rather than above the deck line, where the
      // pools read as small yellow objects instead of light.
      final bool onSpan = x >= _Layout.spanX0 && x <= _Layout.spanX1;
      final double surface = onSpan ? spanY + 2 : _Layout.deckY + 1;
      box(x - 2, surface, x + 2, surface, PixelPalette.lampLit);
      box(x - 1, surface + 1, x + 1, surface + 1, PixelPalette.lampGlow);
      box(x, _Layout.waterY + 2, x, _Layout.waterY + 2, PixelPalette.lampGlow);
    }

    // Red aviation lights near the tops of both pylons, as on the real bridge.
    for (final int x in <int>[
      _Layout.leftTowerX0 + 3,
      _Layout.rightTowerX0 + 3,
    ]) {
      box(x, _Layout.towerTop + 1, x, _Layout.towerTop + 1, PixelPalette.beacon);
    }

    // Near half of the ship, over the structure: it leaves on our side.
    _paintShip(canvas, px, size, near: true);

    if (lift < 0.05) {
      _paintTraffic(canvas, px);
    } else if (maintenance) {
      _paintCones(canvas, px);
    }
  }

  /// The ship crossing the bridge's plane: far side coming in, near side
  /// going out.
  ///
  /// A flat side elevation has no way to show something passing *through* a
  /// structure. Confining the ship to the navigation channel only made it
  /// appear and disappear behind the piers -- still visibly behind the bridge
  /// the whole way. Splitting it at the bridge's centre line and painting the
  /// halves either side of the structure reads as a diagonal pass: it arrives
  /// beyond the bridge and leaves in front of it.
  ///
  /// The seam is invisible because the centre line sits in the open channel,
  /// where there is nothing at hull height to occlude or be occluded. The
  /// effect only becomes visible at the piers, which is where it should.
  void _paintShip(
    Canvas canvas,
    double px,
    Size size, {
    required bool near,
  }) {
    if (lift <= 0.35 || maintenance) return;

    final PixelMatrix ship = PixelMatrix.of(PixelSprites.ship);
    const double centreX = (_Layout.spanX0 + _Layout.spanX1 + 1) / 2;

    final double shipX = animate
        ? -ship.width + drift * (_Layout.width + ship.width)
        // At rest, straddle the centre line so both halves of the effect show.
        : centreX - ship.width / 2;

    canvas.save();
    canvas.clipRect(
      near
          ? Rect.fromLTRB(centreX * px, 0, size.width, size.height)
          : Rect.fromLTRB(0, 0, centreX * px, size.height),
    );
    ship.paint(
      canvas,
      Offset(shipX * px, (_Layout.waterY - ship.height + 3) * px),
      px,
    );
    canvas.restore();
  }

  /// Everything crossing while the bridge is open.
  ///
  /// Six people from the cast, a cyclist, a moto and a car, each at its own
  /// speed and phase so the deck has a trickle of traffic rather than a
  /// parade. Animation frames come from distance travelled, not a timer, so a
  /// stride stays in step with the walking speed and a crank with the
  /// pedalling speed.
  void _paintTraffic(Canvas canvas, double px) {
    const double span = _Layout.width + 60;

    const List<List<String>> blue = <List<String>>[
      PixelSprites.walkBlue0, PixelSprites.walkBlue1,
      PixelSprites.walkBlue2, PixelSprites.walkBlue3,
    ];
    const List<List<String>> pink = <List<String>>[
      PixelSprites.walkPink0, PixelSprites.walkPink1,
      PixelSprites.walkPink2, PixelSprites.walkPink3,
    ];
    const List<List<String>> green = <List<String>>[
      PixelSprites.walkGreen0, PixelSprites.walkGreen1,
      PixelSprites.walkGreen2, PixelSprites.walkGreen3,
    ];
    const List<List<String>> purple = <List<String>>[
      PixelSprites.walkPurple0, PixelSprites.walkPurple1,
      PixelSprites.walkPurple2, PixelSprites.walkPurple3,
    ];
    const List<List<String>> yellow = <List<String>>[
      PixelSprites.walkYellow0, PixelSprites.walkYellow1,
      PixelSprites.walkYellow2, PixelSprites.walkYellow3,
    ];
    const List<List<String>> teal = <List<String>>[
      PixelSprites.walkTeal0, PixelSprites.walkTeal1,
      PixelSprites.walkTeal2, PixelSprites.walkTeal3,
    ];

    // Resting positions are the reduced-motion freeze-frame: spread along both
    // footways and the span, a couple part-way off the edges so it reads as
    // people crossing rather than a line-up.
    const List<_Traveller> traffic = <_Traveller>[
      _Traveller(green, 0.24, 0.05, false, -8, 3),
      _Traveller(blue, 0.30, 0.20, false, 5, 3),
      _Traveller(pink, 0.27, 0.42, true, 19, 3),
      _Traveller(yellow, 0.32, 0.63, false, 30, 3),
      _Traveller(teal, 0.26, 0.78, true, 132, 3),
      _Traveller(purple, 0.29, 0.90, true, 145, 3),
      _Traveller(<List<String>>[PixelSprites.car0, PixelSprites.car1],
          1.00, 0.00, false, 44, 2),
      _Traveller(<List<String>>[PixelSprites.moto0, PixelSprites.moto1],
          1.35, 0.45, false, 82, 2),
      _Traveller(<List<String>>[PixelSprites.cyclist0, PixelSprites.cyclist1],
          0.70, 0.70, true, 112, 2),
    ];

    for (final _Traveller traveller in traffic) {
      final double t = (drift * traveller.speed + traveller.phase) % 1.0;
      final double x = !animate
          ? traveller.restingX
          : traveller.flip
          ? _Layout.width - t * span
          : -40 + t * span;

      final int frame = traveller.frames.length == 1
          ? 0
          : (x / traveller.frameEvery).floor().abs() % traveller.frames.length;

      final PixelMatrix matrix = PixelMatrix.of(traveller.frames[frame]);
      matrix.paint(
        canvas,
        Offset(x * px, (_Layout.deckY - matrix.height) * px),
        px,
        flip: traveller.flip,
      );
    }
  }

  /// Maintenance cones stand on the approach deck, not on the raised span.
  void _paintCones(Canvas canvas, double px) {
    final PixelMatrix cone = PixelMatrix.of(PixelSprites.cone);
    for (final int x in <int>[10, 26, 116]) {
      cone.paint(
        canvas,
        Offset(x * px, (_Layout.deckY - cone.height) * px),
        px,
      );
    }
  }

  @override
  bool shouldRepaint(_BridgeScenePainter old) =>
      old.lift != lift ||
      old.drift != drift ||
      old.animate != animate ||
      old.maintenance != maintenance;
}
