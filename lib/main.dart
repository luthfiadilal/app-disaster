import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/post_controller.dart';
import 'providers/auth_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/screens/post_screen.dart'; // Keeping this for reference

import 'package:latlong2/latlong.dart';
import 'views/home/home_screen.dart';
import 'views/reports/create_report_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostController()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Disaster GIS App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/create-report') {
            final args = settings.arguments as LatLng;
            return MaterialPageRoute(
              builder: (context) {
                return CreateReportScreen(point: args);
              },
            );
          }
          return null;
        },
      ),
    );
  }
}
