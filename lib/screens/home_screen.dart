import 'package:flutter/material.dart';
import '../utils/platform_helper.dart';

import 'home_screen_mobile.dart';
import 'home_screen_web.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (isWebOrDesktopLayout(context)) {
      return const HomeScreenWeb();
    } else {
      return const HomeScreenMobile();
    }
  }
}
