import 'package:material_ui/material_ui.dart';

import 'screens/builder_screen.dart';
import 'theme.dart';

void main() {
  runApp(const TalkBuilderApp());
}

class TalkBuilderApp extends StatelessWidget {
  const TalkBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk Builder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      // reorderable_grid_view imports package:flutter/material.dart, so its
      // widgets read the theme and the localisations of that library. The
      // bridge gives them this app's theme. material_ui marks the bridge as
      // deprecated because it is a temporary aid.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
      home: const BuilderScreen(),
    );
  }
}
