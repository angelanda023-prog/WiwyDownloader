import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Fila de sitios soportados (YouTube, Facebook, Instagram, TikTok, …).
/// Dibujada sin dependencias externas: círculo de marca + glifo/letra.
class SiteIconsRow extends StatelessWidget {
  const SiteIconsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final sites = <_Site>[
      _Site('YouTube', const Color(0xFFFF0000), icon: Icons.play_arrow_rounded),
      _Site('Facebook', const Color(0xFF1877F2), letter: 'f'),
      _Site('Instagram', const Color(0xFFE1306C),
          icon: Icons.camera_alt_outlined, gradient: _instaGradient),
      _Site('TikTok', const Color(0xFF000000),
          icon: Icons.music_note, bordered: true),
      _Site('Twitter', const Color(0xFF1DA1F2), letter: '𝕏'),
      _Site('Vimeo', const Color(0xFF1AB7EA), letter: 'V'),
      _Site('SoundCloud', const Color(0xFFFF5500), icon: Icons.cloud),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: sites.map((s) => _SiteBadge(site: s)).toList(),
    );
  }
}

const _instaGradient = LinearGradient(
  colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _Site {
  final String name;
  final Color color;
  final IconData? icon;
  final String? letter;
  final Gradient? gradient;
  final bool bordered;
  _Site(
    this.name,
    this.color, {
    this.icon,
    this.letter,
    this.gradient,
    this.bordered = false,
  });
}

class _SiteBadge extends StatelessWidget {
  final _Site site;
  const _SiteBadge({required this.site});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: site.gradient == null ? site.color : null,
        gradient: site.gradient,
        border: site.bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: Center(
        child: site.letter != null
            ? Text(site.letter!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800))
            : Icon(site.icon, color: Colors.white, size: 20),
      ),
    );
  }
}
