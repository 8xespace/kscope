import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const KaleidoscopeApp());
}

class KaleidoscopeApp extends StatelessWidget {
  const KaleidoscopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaleidoscope – Octagon Core Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const KaleidoscopePage(),
    );
  }
}

class KaleidoscopePage extends StatefulWidget {
  const KaleidoscopePage({super.key});

  @override
  State<KaleidoscopePage> createState() => _KaleidoscopePageState();
}

class _KaleidoscopePageState extends State<KaleidoscopePage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _shakeController;

  static const int _segmentCount = 8;

  double _timePhase = 0.0;
  double _lastControllerValue = 0.0;

  int _direction = 1;
  int _patternSeed = 0;

  // 手機陀螺儀角度控制
  double _gyroAngle = 0.0;
  DateTime? _lastGyroSampleTime;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

    // 色塊流動動畫
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )
      ..addListener(_tick)
      ..repeat();

    // 搖晃特效動畫
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    if (_isMobile) {
      _startGyro();
      _startShakeFromAccelerometer();
    }
  }

  void _tick() {
    final double v = _controller.value;
    double dv = v - _lastControllerValue;
    if (dv < 0) dv += 1.0;
    _timePhase += dv;
    _lastControllerValue = v;
  }

  // ====================== 陀螺儀（高靈敏度） ======================
  void _startGyro() {
    const double gyroSensitivity = 1.8; // 可調整靈敏度

    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent e) {
      final DateTime now = DateTime.now();

      if (_lastGyroSampleTime == null) {
        _lastGyroSampleTime = now;
        return;
      }

      double dt =
          now.difference(_lastGyroSampleTime!).inMicroseconds / 1e6;
      _lastGyroSampleTime = now;

      // 避免某一筆異常延遲
      dt = dt.clamp(0.0, 0.05);

      setState(() {
        // e.z: rad/s，乘 dt 得到 rad
        _gyroAngle += e.z * dt * gyroSensitivity;
      });
    });
  }

  // ====================== 手機搖晃偵測 ======================
  void _startShakeFromAccelerometer() {
    const double shakeThreshold = 13.5;

    _accelSub = accelerometerEvents.listen((AccelerometerEvent e) {
      final double mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (mag > shakeThreshold) {
        _triggerReset();
      }
    });
  }

  void _triggerReset() {
    setState(() {
      _patternSeed++;
    });
    _shakeController.forward(from: 0.0);
  }

  // 桌面：單擊切換順/逆
  void _toggleDirection() {
    if (_isMobile) return;
    setState(() {
      _direction = -_direction;
    });
  }

  // 桌面：雙擊重置
  void _desktopDoubleTap() {
    if (_isMobile) return;
    _triggerReset();
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    _gyroSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isMobile ? null : _toggleDirection,
      onDoubleTap: _isMobile ? null : _desktopDoubleTap,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation:
                    Listenable.merge([_controller, _shakeController]),
                builder: (context, _) {
                  const double desktopSpeed = 0.7;

                  final double baseRotation = _isMobile
                      ? _gyroAngle
                      : 2 *
                          pi *
                          _timePhase *
                          desktopSpeed *
                          _direction;

                  return CustomPaint(
                    size: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                    painter: OctagonKaleidoscopePainter(
                      time: _timePhase,
                      segmentCount: _segmentCount,
                      direction: _direction,
                      patternSeed: _patternSeed,
                      shake: _shakeController.value,
                      baseRotation: baseRotation,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// 萬花筒 Painter
// ===================================================================
class OctagonKaleidoscopePainter extends CustomPainter {
  final double time;
  final int segmentCount;
  final int direction;
  final int patternSeed;
  final double shake;
  final double baseRotation;

  OctagonKaleidoscopePainter({
    required this.time,
    required this.segmentCount,
    required this.direction,
    required this.patternSeed,
    required this.shake,
    required this.baseRotation,
  });

  static const int _blobCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final double minSide = min(size.width, size.height);
    final double coreRadius = minSide / 2;
    final double maxRadius =
        sqrt(size.width * size.width + size.height * size.height);

    final Offset center = Offset(size.width / 2, size.height / 2);

    // ------------ 背景 ------------
    final Paint bg = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF02030A),
          Color(0xFF060A1C),
          Color(0xFF02030A),
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawRect(Offset.zero & size, bg);

    // 移到中心
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double wedgeAngle = 2 * pi / segmentCount;
    final Path wedgeClip = _buildWedgeClip(maxRadius, wedgeAngle * 0.98);

    double shakeAngle = 0.0;
    if (shake > 0.0) {
      final double s = shake;
      shakeAngle = sin(s * 10 * pi) * (0.4 * pi * (1.0 - s));
    }

    final double globalRot = baseRotation + shakeAngle;
    canvas.rotate(globalRot);

    // 每一片鏡射區
    for (int seg = 0; seg < segmentCount; seg++) {
      canvas.save();
      canvas.rotate(wedgeAngle * seg);

      if (seg.isOdd) {
        canvas.scale(1.0, -1.0);
      }

      canvas.clipPath(wedgeClip);

      for (int i = 0; i < _blobCount; i++) {
        _drawBlob(canvas, coreRadius, maxRadius, wedgeAngle, i);
      }

      canvas.restore();
    }

    canvas.restore();

    // 中心八角形（修正版）
    _drawCenterOctagon(canvas, size, globalRot);

    // 暗角 + 顆粒
    _drawVignette(canvas, size);
    _drawNoise(canvas, size);
  }

  // -------------- 色塊 Blob --------------
  void _drawBlob(Canvas canvas, double coreRadius, double maxRadius,
      double wedgeAngle, int index) {
    double rnd(int salt) =>
        sin((patternSeed * 9127 + index * 37 + salt) * 12.9898) %
        1;

    final double t = time;

    final double rR = rnd(1).abs();
    final double aR = rnd(2).abs();
    final double sR = rnd(3).abs();
    final double cR = rnd(4).abs();

    final double rInner = coreRadius * 0.12;
    final double rOuter = maxRadius * 0.95;
    final double u = pow(rR, 1.1).toDouble();

    final double baseR = rInner + (rOuter - rInner) * u;
    final double r = baseR *
        (1.0 +
            0.15 *
                sin(2 * pi * (t * (0.7 + rR) + aR * 1.3)));

    final double localAngle = (aR - 0.5) * wedgeAngle * 0.9 +
        0.15 *
            wedgeAngle *
            sin(2 * pi * (t * (1.1 + aR) + sR * 2.1));

    final Offset center = Offset(
      r * cos(localAngle),
      r * sin(localAngle),
    );

    final double baseSize = coreRadius * (0.07 + 0.10 * sR);
    final double size =
        baseSize *
            (0.85 + 0.3 * sin(2 * pi * (t * (1.4 + sR) + rR * 2.7)));

    final double stretchX = 1.0 + 0.9 * sR;
    final double stretchY = 0.7 + 0.6 * (1 - sR);
    final double orientation = 2 * pi * sR + 2 * pi * t * (0.4 + rR);

    final double hue =
        (360.0 * t * 1.1 + cR * 200.0 + index * 9.0) % 360.0;

    final Color color = HSVColor.fromAHSV(
      0.95,
      hue,
      0.9,
      0.75,
    ).toColor();

    final double depth =
        ((baseR - rInner) / (rOuter - rInner)).clamp(0.0, 1.0);
    final double sigma =
        coreRadius * 0.002 + coreRadius * 0.028 * pow(depth, 1.4);

    final Paint paint = Paint()
      ..color = color
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    final Paint glow = Paint()
      ..color = color.withOpacity(0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma * 1.3);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orientation);
    canvas.scale(stretchX, stretchY);

    final Rect rect = Rect.fromCircle(center: Offset.zero, radius: size);

    canvas.drawOval(rect.inflate(size * 0.18), glow);
    canvas.drawOval(rect, paint);

    canvas.restore();
  }

  // -------------- 中心八角形（修正版） --------------
  void _drawCenterOctagon(Canvas canvas, Size size, double rot) {
    final double minSide = min(size.width, size.height);
    final double r = minSide * 0.19; // 八角形半徑
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Path octagon = Path();
    for (int i = 0; i < 8; i++) {
      final double ang = (2 * pi * i / 8) + pi / 8;
      final Offset p = Offset(
        r * cos(ang),
        r * sin(ang),
      );
      if (i == 0) {
        octagon.moveTo(p.dx, p.dy);
      } else {
        octagon.lineTo(p.dx, p.dy);
      }
    }
    octagon.close();

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.15
      ..color = Colors.white.withOpacity(0.15)
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, r * 0.12);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = Colors.white.withOpacity(0.8);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);

    // 此時八角形是以原點為中心建構，所以直接畫即可
    canvas.drawPath(octagon, glow);
    canvas.drawPath(octagon, border);

    canvas.restore();
  }

  // -------------- 暗角 Vignette --------------
  void _drawVignette(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius =
        sqrt(size.width * size.width + size.height * size.height) / 2;

    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.58),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.darken;

    canvas.drawRect(Offset.zero & size, p);
  }

  // -------------- 顆粒 Noise --------------
  void _drawNoise(Canvas canvas, Size size) {
    final double step = 6;
    final int frame = (time * 60).floor();

    final Paint p = Paint();

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        double noise = _hash3(x.toInt(), y.toInt(), frame);
        if (noise < 0.82) continue;

        final double alpha = (noise - 0.82) / 0.18 * 0.12;

        p.color = Color.fromARGB(
          (alpha * 255).clamp(6, 32).toInt(),
          240,
          240,
          240,
        );

        canvas.drawRect(
          Rect.fromLTWH(x, y, 1.2, 1.2),
          p,
        );
      }
    }
  }

  double _hash3(int x, int y, int z) {
    int n = x * 15731 ^ y * 789221 ^ z * 1376312589;
    n = (n << 13) ^ n;
    return (1.0 -
            ((n * (n * n * 15731 + 789221) + 1376312589)
                    & 0x7fffffff) /
                1073741824.0)
        .abs();
  }

  Path _buildWedgeClip(double radius, double angle) {
    final double half = angle / 2;
    final Offset p1 = Offset(radius * cos(-half), radius * sin(-half));
    final Offset p2 = Offset(radius * cos(half), radius * sin(half));
    return Path()
      ..moveTo(0, 0)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant OctagonKaleidoscopePainter old) {
    return old.time != time ||
        old.segmentCount != segmentCount ||
        old.direction != direction ||
        old.patternSeed != patternSeed ||
        old.shake != shake ||
        old.baseRotation != baseRotation;
  }
}
