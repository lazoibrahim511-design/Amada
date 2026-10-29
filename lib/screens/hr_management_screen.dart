import 'package:flutter/material.dart';
import '../utils/platform_helper.dart';

import 'hr_management_screen_mobile.dart';
import 'hr_management_screen_web.dart';

enum HrTab {
  structures,
  shifts,
  groups,
  employees,
  holidays,
  locations,
  payroll,
  dailyReport,
  periodicReport,
  device,
}

class HrManagementScreen extends StatelessWidget {
  final HrTab? initialTab;
  final bool isEmbedded;

  const HrManagementScreen({
    super.key,
    this.initialTab,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isWebOrDesktopLayout(context)) {
      return HrManagementScreenWeb(
        initialTab: initialTab,
        isEmbedded: isEmbedded,
      );
    } else {
      return HrManagementScreenMobile(
        initialTab: initialTab,
        isEmbedded: isEmbedded,
      );
    }
  }
}
