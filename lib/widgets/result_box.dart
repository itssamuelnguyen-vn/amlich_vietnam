import 'package:flutter/material.dart';

import '../theme.dart';

/// The red-and-gold result panel shared by the tools.
class ResultBox extends StatelessWidget {
  const ResultBox({super.key, required this.big, required this.lines, this.action});

  final String big;
  final List<String> lines;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final lich = context.lich;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [lich.heroTop, lich.heroBottom]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('KẾT QUẢ', style: TextStyle(color: lich.gold, fontSize: 11, letterSpacing: 1.5)),
          Text(
            big,
            style: TextStyle(color: lich.onHero, fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w700),
          ),
          for (final l in lines) Text(l, style: TextStyle(color: lich.onHero.withValues(alpha: 0.85), fontSize: 14)),
          ?action,
        ],
      ),
    );
  }
}
