import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/builder_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide the status and navigation bars. The app is meant to run pinned on a
  // child's tablet, and a visible navigation bar is the easiest way out of it.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
      home: const BuilderScreen(),
    );
  }
}
