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
      title: 'Kaleidoscope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const SplashIntroPage(),
    );
  }
}

/// ===================================================================
/// 片頭：logo + 「頂極制作所」+ 白色底 + 彩繪點狀 + 背景動畫 + 進度條（固定 3 秒）
/// - logo 逆時針旋轉 360 度 / 3 秒
/// ===================================================================
class SplashIntroPage extends StatefulWidget {
  const SplashIntroPage({super.key});

  @override
  State<SplashIntroPage> createState() => _SplashIntroPageState();
}

class _SplashIntroPageState extends State<SplashIntroPage>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // 3 秒固定進度
  late final AnimationController _bgLoop; // 白底特效循環（更明顯）

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _bgLoop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => const KaleidoscopePage(),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _bgLoop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _bgLoop]),
        builder: (context, _) {
          final tProgress = _intro.value.clamp(0.0, 1.0);
          final tBg = _bgLoop.value.clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 更明顯的白底流動背景（流光帶 + 墨滴）
              CustomPaint(
                painter: IntroFlowBackgroundPainter(time: tBg),
              ),

              // 強化版紅色彩繪濺點（可視感更強）
              CustomPaint(
                painter: IntroRedDotPaintPainter(time: tBg),
              ),

              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: min(170.0, w * 0.34),
                          height: min(170.0, w * 0.34),
                          child: Transform.rotate(
                            angle: -2 * pi * tProgress,
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.auto_awesome,
                                        size: 54, color: Colors.black54),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '頂極制作所',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            letterSpacing: 3.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withOpacity(0.86),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Kaleidoscope Engine',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 2.0,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 26),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 10,
                            child: LinearProgressIndicator(
                              value: tProgress,
                              backgroundColor: Colors.black.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black.withOpacity(0.70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '正在啟動視覺核心…',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 輕微暗角（讓白底更有層次）
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                      ],
                      stops: const [0.70, 1.0],
                      radius: 1.25,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// ===================================================================
/// 白底背景動畫（加強可視感）：流光帶 + 漂浮墨滴 + 微雜訊
/// ===================================================================
class IntroFlowBackgroundPainter extends CustomPainter {
  final double time;
  IntroFlowBackgroundPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // 乾淨白底（帶一點冷色層次）
    final bg = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xFFF3F6FF),
          Color(0xFFFFFFFF),
        ],
        stops: const [0.0, 0.68, 1.0],
      ).createShader(Rect.fromCircle(
        center: c,
        radius: sqrt(size.width * size.width + size.height * size.height) / 2,
      ));
    canvas.drawRect(Offset.zero & size, bg);

    final t = time;

    // ----------------------------
    // 01) 明顯的流光帶（淡藍/淡紫/淡青）
    // ----------------------------
    const bandCount = 7;
    for (int i = 0; i < bandCount; i++) {
      final k = i / (bandCount - 1);
      final phase = 2 * pi * (t * 0.85 + k);

      final y = size.height * (0.15 + 0.70 * k) + sin(phase) * (18 + 26 * (1 - k));
      final thickness = 34 + 56 * (1 - k);

      final rect = Rect.fromLTWH(
        -size.width * 0.25,
        y - thickness / 2,
        size.width * 1.50,
        thickness,
      );

      final alpha = 0.10 + 0.10 * (1 - k); // 比你原本強很多，白底一定看得到

      final p = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF7EA3FF).withOpacity(alpha),
            const Color(0xFFA58BFF).withOpacity(alpha * 0.75),
            const Color(0xFF7FE7FF).withOpacity(alpha * 0.65),
            Colors.transparent,
          ],
          stops: const [0.0, 0.40, 0.55, 0.70, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.screen;

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(0.10 * sin(2 * pi * (t + k)));
      canvas.translate(-c.dx, -c.dy);
      canvas.drawRect(rect, p);
      canvas.restore();
    }

    // ----------------------------
    // 02) 漂浮墨滴（低成本，效果明顯）
    // ----------------------------
    final dropletPaint = Paint()..blendMode = BlendMode.multiply;
    const int dropletCount = 16;

    for (int i = 0; i < dropletCount; i++) {
      final rx = _hash3(i, (t * 1000).floor(), 11);
      final ry = _hash3(i, (t * 1000).floor(), 29);
      final rr = _hash3(i, (t * 1000).floor(), 47);

      final x = (0.08 + 0.84 * rx) * size.width;
      final y = (0.10 + 0.80 * ry) * size.height;

      final base = 28 + 70 * rr;
      final pulse = 0.88 + 0.20 * sin(2 * pi * (t * (0.7 + rr) + rx));
      final r = base * pulse;

      final hue = (200 + 120 * _hash3(i, (t * 1000).floor(), 71)) % 360;
      final col = HSVColor.fromAHSV(
        (0.05 + 0.10 * rr).clamp(0.05, 0.14),
        hue,
        0.55,
        0.98,
      ).toColor();

      dropletPaint.color = col;
      canvas.drawCircle(Offset(x, y), r, dropletPaint);
    }

    // ----------------------------
    // 03) 微雜訊（避免白底太死）
    // ----------------------------
    const step = 9.0;
    final frame = (t * 120).floor();
    final noisePaint = Paint();

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final n = _hash3(x.toInt(), y.toInt(), frame);
        if (n < 0.88) continue;
        final a = ((n - 0.88) / 0.12) * 0.06;

        noisePaint.color = Color.fromARGB(
          (a * 255).clamp(4, 16).toInt(),
          0,
          0,
          0,
        );
        canvas.drawRect(Rect.fromLTWH(x, y, 1.3, 1.3), noisePaint);
      }
    }
  }

  double _hash3(int a, int b, int c) {
    int n = a * 15731 ^ b * 789221 ^ c * 1376312589;
    n = (n << 13) ^ n;
    return (1.0 -
            ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
                1073741824.0)
        .abs();
  }

  @override
  bool shouldRepaint(covariant IntroFlowBackgroundPainter old) => old.time != time;
}

/// 片頭：紅色點狀彩繪（白底上看得到、有質感、成本低）
/// ※ 這版加強「可見度」：點更大、alpha 更高、密度更合理
class IntroRedDotPaintPainter extends CustomPainter {
  final double time;
  IntroRedDotPaintPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final t = time;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.10 * sin(2 * pi * t));
    canvas.translate(-c.dx, -c.dy);

    final int seed = (t * 600).floor();
    final Paint p = Paint()..blendMode = BlendMode.multiply;

    // 顆粒更明顯
    const int count = 320;
    for (int i = 0; i < count; i++) {
      final double rx = _hash3(i, seed, 17);
      final double ry = _hash3(i, seed, 41);

      final dx = rx - 0.5;
      final dy = ry - 0.5;
      final d = sqrt(dx * dx + dy * dy);

      // 中央稍微稀一點，避免蓋住 logo 區域
      if (d < 0.18 && _hash3(i, seed, 99) < 0.68) continue;

      final x = rx * size.width;
      final y = ry * size.height;

      // 點尺寸加大
      final double s = 1.6 + 5.4 * _hash3(i, seed, 73);

      // alpha 加強，白底一定看得到
      final double a = (0.08 + 0.26 * _hash3(i, seed, 111)) * (0.35 + d);

      final double hue = (6 + 26 * _hash3(i, seed, 7)) % 360;
      final Color col =
          HSVColor.fromAHSV(a.clamp(0.0, 0.30), hue, 0.90, 0.98).toColor();

      p.color = col;
      canvas.drawCircle(Offset(x, y), s, p);

      // 拖尾點（更有彩繪筆刷感）
      if (_hash3(i, seed, 121) > 0.78) {
        p.color = col.withOpacity((a * 0.55).clamp(0.0, 0.22));
        canvas.drawCircle(Offset(x + s * 1.8, y - s * 1.1), s * 0.70, p);
        if (_hash3(i, seed, 131) > 0.85) {
          canvas.drawCircle(Offset(x - s * 1.2, y + s * 0.9), s * 0.55, p);
        }
      }
    }

    canvas.restore();
  }

  double _hash3(int a, int b, int c) {
    int n = a * 15731 ^ b * 789221 ^ c * 1376312589;
    n = (n << 13) ^ n;
    return (1.0 -
            ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
                1073741824.0)
        .abs();
  }

  @override
  bool shouldRepaint(covariant IntroRedDotPaintPainter old) => old.time != time;
}

/// ===================================================================
/// 主畫面：萬花筒（含分片數切換撥桿）
/// ===================================================================
class KaleidoscopePage extends StatefulWidget {
  const KaleidoscopePage({super.key});

  @override
  State<KaleidoscopePage> createState() => _KaleidoscopePageState();
}

class _KaleidoscopePageState extends State<KaleidoscopePage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _shakeController;

  static const List<int> _segmentOptions = [6, 8, 12, 16];
  int _segmentCount = 8;

  double _timePhase = 0.0;
  double _lastControllerValue = 0.0;

  int _direction = 1;
  int _patternSeed = 0;

  double _gyroRawAngle = 0.0;
  DateTime? _lastGyroSampleTime;

  double _gyroSmoothAngle = 0.0;
  double _oscPos = 0.0;
  double _oscVel = 0.0;
  double _mobileRotationOut = 0.0;

  static const double _steadyGain = 30.0;
  static const double _transientGain = 10.0;

  static const double _omega = 10.0;
  static const double _zeta = 0.35;

  static const double _smoothTau = 0.10;

  DateTime? _lastFrameTime;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )
      ..addListener(_tick)
      ..repeat();

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

    if (_isMobile) {
      final now = DateTime.now();
      _lastFrameTime ??= now;
      double dt = now.difference(_lastFrameTime!).inMicroseconds / 1e6;
      _lastFrameTime = now;
      dt = dt.clamp(0.0, 0.05);

      final alpha = 1.0 - exp(-dt / _smoothTau);
      _gyroSmoothAngle += (_gyroRawAngle - _gyroSmoothAngle) * alpha;

      final acc =
          -(_omega * _omega) * _oscPos - (2.0 * _zeta * _omega) * _oscVel;
      _oscVel += acc * dt;
      _oscPos += _oscVel * dt;

      _mobileRotationOut = (_gyroSmoothAngle * _steadyGain) + _oscPos;
    }
  }

  void _startGyro() {
    const double gyroSensitivity = 1.8;

    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent e) {
      final DateTime now = DateTime.now();

      if (_lastGyroSampleTime == null) {
        _lastGyroSampleTime = now;
        return;
      }

      double dt = now.difference(_lastGyroSampleTime!).inMicroseconds / 1e6;
      _lastGyroSampleTime = now;
      dt = dt.clamp(0.0, 0.05);

      final double delta = e.z * dt * gyroSensitivity;

      _gyroRawAngle += delta;

      _oscVel += (delta * _transientGain) * (_omega * 1.0);
    });
  }

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

  void _toggleDirection() {
    if (_isMobile) return;
    setState(() {
      _direction = -_direction;
    });
  }

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
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_controller, _shakeController]),
                    builder: (context, _) {
                      const double desktopSpeed = 0.7;

                      final double baseRotation = _isMobile
                          ? _mobileRotationOut
                          : 2 * pi * _timePhase * desktopSpeed * _direction;

                      return CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
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
                  ),

                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _SegmentControl(
                      segmentCount: _segmentCount,
                      options: _segmentOptions,
                      onChanged: (v) {
                        setState(() {
                          _segmentCount = v;
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 右下角控制：6 / 8 / 12 / 16
class _SegmentControl extends StatelessWidget {
  final int segmentCount;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _SegmentControl({
    required this.segmentCount,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int idx = options.indexOf(segmentCount).clamp(0, options.length - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '分片：$segmentCount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.88),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 170,
            child: Slider(
              value: idx.toDouble(),
              min: 0,
              max: (options.length - 1).toDouble(),
              divisions: options.length - 1,
              onChanged: (v) {
                final n = options[v.round().clamp(0, options.length - 1)];
                if (n != segmentCount) onChanged(n);
              },
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((e) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        '$e',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white
                              .withOpacity(e == segmentCount ? 0.95 : 0.45),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// ===================================================================
/// 萬花筒 Painter
/// ===================================================================
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

  static const int _blobCount = 42;

  @override
  void paint(Canvas canvas, Size size) {
    final double minSide = min(size.width, size.height);
    final double coreRadius = minSide / 2;
    final double maxRadius =
        sqrt(size.width * size.width + size.height * size.height);

    final Offset center = Offset(size.width / 2, size.height / 2);

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

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double wedgeAngle = 2 * pi / segmentCount;
    final Path wedgeClip = _buildWedgeClip(maxRadius * 1.2, wedgeAngle * 0.985);

    double shakeAngle = 0.0;
    if (shake > 0.0) {
      final double s = shake;
      shakeAngle = sin(s * 10 * pi) * (0.42 * pi * (1.0 - s));
    }

    final double globalRot = baseRotation + shakeAngle;
    canvas.rotate(globalRot);

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

    _drawCenterOctagon(canvas, size, globalRot);

    _drawOuterSoftBlur(canvas, size);
    _drawVignette(canvas, size);
    _drawNoise(canvas, size);
  }

  void _drawBlob(Canvas canvas, double coreRadius, double maxRadius,
      double wedgeAngle, int index) {
    double rnd(int salt) =>
        sin((patternSeed * 9127 + index * 37 + salt) * 12.9898) % 1;

    final double t = time;

    final double rR = rnd(1).abs();
    final double aR = rnd(2).abs();
    final double sR = rnd(3).abs();
    final double cR = rnd(4).abs();

    final double rInner = coreRadius * 0.10;
    final double rOuter = maxRadius * 0.98;
    final double u = pow(rR, 1.05).toDouble();

    final double baseR = rInner + (rOuter - rInner) * u;
    final double r = baseR *
        (1.0 + 0.16 * sin(2 * pi * (t * (0.7 + rR) + aR * 1.3)));

    final double localAngle = (aR - 0.5) * wedgeAngle * 0.92 +
        0.16 * wedgeAngle * sin(2 * pi * (t * (1.1 + aR) + sR * 2.1));

    final Offset center = Offset(r * cos(localAngle), r * sin(localAngle));

    final double baseSize = coreRadius * (0.075 + 0.11 * sR);
    final double size = baseSize *
        (0.86 + 0.30 * sin(2 * pi * (t * (1.35 + sR) + rR * 2.7)));

    final double stretchX = 1.0 + 0.95 * sR;
    final double stretchY = 0.68 + 0.70 * (1 - sR);
    final double orientation = 2 * pi * sR + 2 * pi * t * (0.38 + rR);

    final double hue = (360.0 * t * 1.15 + cR * 220.0 + index * 9.0) % 360.0;

    final Color color = HSVColor.fromAHSV(
      0.95,
      hue,
      0.92,
      0.80,
    ).toColor();

    final double depth =
        ((baseR - rInner) / (rOuter - rInner)).clamp(0.0, 1.0);
    final double sigma =
        coreRadius * 0.002 + coreRadius * 0.030 * pow(depth, 1.35);

    final Paint paint = Paint()
      ..color = color
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    final Paint glow = Paint()
      ..color = color.withOpacity(0.46)
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma * 1.35);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(orientation);
    canvas.scale(stretchX, stretchY);

    final Rect rect = Rect.fromCircle(center: Offset.zero, radius: size);

    canvas.drawOval(rect.inflate(size * 0.18), glow);
    canvas.drawOval(rect, paint);

    canvas.restore();
  }

  void _drawCenterOctagon(Canvas canvas, Size size, double rot) {
    final double minSide = min(size.width, size.height);
    final double r = minSide * 0.19;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Path octagon = Path();
    for (int i = 0; i < 8; i++) {
      final double ang = (2 * pi * i / 8) + pi / 8;
      final Offset p = Offset(r * cos(ang), r * sin(ang));
      if (i == 0) {
        octagon.moveTo(p.dx, p.dy);
      } else {
        octagon.lineTo(p.dx, p.dy);
      }
    }
    octagon.close();

    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..color = Colors.white.withOpacity(0.14)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = Colors.white.withOpacity(0.82);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);

    canvas.drawPath(octagon, glow);
    canvas.drawPath(octagon, border);

    canvas.restore();
  }

  void _drawOuterSoftBlur(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double r =
        sqrt(size.width * size.width + size.height * size.height) / 2;

    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.10),
          Colors.black.withOpacity(0.18),
        ],
        stops: const [0.62, 0.86, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.018)
      ..blendMode = BlendMode.darken;

    canvas.drawRect(Offset.zero & size, p);
  }

  void _drawVignette(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius =
        sqrt(size.width * size.width + size.height * size.height) / 2;

    final Paint p = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.60),
        ],
        stops: const [0.56, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.darken;

    canvas.drawRect(Offset.zero & size, p);
  }

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
          (alpha * 255).clamp(6, 34).toInt(),
          240,
          240,
          240,
        );

        canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), p);
      }
    }
  }

  double _hash3(int x, int y, int z) {
    int n = x * 15731 ^ y * 789221 ^ z * 1376312589;
    n = (n << 13) ^ n;
    return (1.0 -
            ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
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
