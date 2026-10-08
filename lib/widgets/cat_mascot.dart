import 'package:flutter/widgets.dart';

class CatMascot extends StatelessWidget {
  const CatMascot({super.key, this.size = 64, this.removePadding = false});

  final double size;
  final bool removePadding;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/cat_mascot.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    if (!removePadding) return image;

    return ClipRect(
      child: Transform.scale(scale: 173 / 74, child: image),
    );
  }
}
