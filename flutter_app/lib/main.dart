import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  const api = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');
  runApp(const VoteApp(apiBaseUrl: api));
}

class VoteApp extends StatefulWidget {
  const VoteApp({super.key, required this.apiBaseUrl});
  final String apiBaseUrl;
  @override State<VoteApp> createState() => _VoteAppState();
}

class _VoteAppState extends State<VoteApp> {
  ThemeMode mode = ThemeMode.system;
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kiểm đếm phiếu bầu Pro',
    themeMode: mode,
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true, brightness: Brightness.light),
    darkTheme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true, brightness: Brightness.dark),
    home: HomeScreen(apiBaseUrl: widget.apiBaseUrl),
  );
}
