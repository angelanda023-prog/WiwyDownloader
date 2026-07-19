import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Logo de la barra: emblema "W" + "Wiwy" (naranja) "Downloader" (blanco).
///
/// Cuando pongas el PNG del logo en assets/icon/wiwy_icon.png puedes cambiar
/// [_Emblem] por `Image.asset('assets/icon/wiwy_icon.png', height: 34)`.
class WiwyLogo extends StatelessWidget {
  const WiwyLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Emblem(),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            children: [
              TextSpan(text: 'Wiwy', style: TextStyle(color: AppColors.orange)),
              TextSpan(
                  text: 'Downloader',
                  style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aro naranja incompleto (como el del logo)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.orange, width: 2.5),
            ),
          ),
          ShaderMask(
            shaderCallback: (r) => AppColors.orangeGradient.createShader(r),
            child: const Text('W',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          Positioned(
            bottom: -2,
            child: Icon(Icons.arrow_downward_rounded,
                color: AppColors.orange, size: 12),
          ),
        ],
      ),
    );
  }
}
