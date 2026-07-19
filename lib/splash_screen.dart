import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'home_screen.dart';

/// Bienvenida estilo WiwyPlay/WiwyFood: el logo entra con un rebote → una
/// onda (destello) NARANJA pulsa → se desliza el nombre "WiwyDownloader" →
/// entra a la app.
///
/// Usa un reloj real (Stopwatch + Timer), no AnimationController, para que la
/// animación se vea aunque el dispositivo tenga las animaciones desactivadas.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const int _durMs = 2600;
  final Stopwatch _sw = Stopwatch();
  Timer? _timer;
  double _t = 0;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _sw.start();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ms = _sw.elapsedMilliseconds;
      if (!mounted) return;
      setState(() => _t = (ms / _durMs).clamp(0.0, 1.0));
      if (ms >= _durMs && !_gone) {
        _gone = true;
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScaffold()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sw.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final logoIn = Curves.easeOutBack.transform((t / 0.32).clamp(0.0, 1.0));
    final glow = (t > 0.30 && t < 0.62) ? sin((t - 0.30) / 0.32 * pi) : 0.0;
    final textT = Curves.easeOut.transform(((t - 0.55) / 0.32).clamp(0.0, 1.0));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 26,
            child: Center(
              child: Text('Wiwy Downloader',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.6 + 0.4 * logoIn,
                  child: Opacity(
                    opacity: logoIn.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          // La "onda" naranja que pulsa alrededor del logo.
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.6 * glow),
                            blurRadius: 40 * glow,
                            spreadRadius: 8 * glow,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icon/hero_download.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: textT,
                    child: Opacity(
                      opacity: textT,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 22),
                            children: [
                              TextSpan(
                                  text: 'Wiwy',
                                  style: TextStyle(color: AppColors.orange)),
                              TextSpan(
                                  text: 'Downloader',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
