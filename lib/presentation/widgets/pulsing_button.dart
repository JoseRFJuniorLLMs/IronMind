import 'package:flutter/material.dart';

class PulsingButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData? icon; // ✅ Agora opcional
  final String label;
  final double size;
  final String? imagePath; // ✅ NEW: Para fundo com imagem (ex: oceano_azul.jpg)

  const PulsingButton({
    super.key,
    required this.onTap,
    this.icon,
    required this.label,
    this.size = 200,
    this.imagePath,
  });

  @override
  _PulsingButtonState createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<PulsingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _glowAnimation = Tween<double>(
      begin: 10.0,
      end: 30.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: widget.imagePath != null
                    ? DecorationImage(
                        image: AssetImage(widget.imagePath!),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: widget.imagePath == null
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF69B4), // Pink Hot
                          Color(0xFFC71585), // Medium Violet Red
                        ],
                      )
                    : null,
                boxShadow: [
                  // Glow pulsante
                  BoxShadow(
                    color: const Color(0xFFFF1493).withValues(alpha: 0.6),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 2,
                  ),
                  // Sombra 3D
                  const BoxShadow(
                    color: Colors.black45,
                    offset: Offset(4, 8),
                    blurRadius: 10,
                  ),
                  // Highlight superior (efeito vidro/3D)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    offset: const Offset(-4, -4),
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 4,
                ),
              ),
              child: widget.imagePath != null
                  ? const SizedBox.shrink() // Oculta texto se houver imagem
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✅ Renderizar ícone SOMENTE se existir
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: Colors.white,
                            size: widget.size * 0.4,
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          widget.label.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
