import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Launch screen: logo + app name + slogan in the center, "From Zeroex" at the bottom.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const cream = Color(0xFFFAF4E6);
  static const gold = Color(0xFFB8935A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/logo.png', width: 150),
                    const SizedBox(height: 20),
                    const Text('Annua',
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.w300, letterSpacing: 4, color: gold)),
                    const SizedBox(height: 10),
                    Text("Don't miss any events or birthdays",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, letterSpacing: .5, color: gold.withValues(alpha: .85))),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('From', style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: gold.withValues(alpha: .7))),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/brands/zeroex.svg', height: 26),
                const SizedBox(width: 8),
                const Text('Zeroex', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2, color: gold)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
