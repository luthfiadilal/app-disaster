import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/post_controller.dart';
import 'providers/auth_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';

import 'package:latlong2/latlong.dart';
import 'views/home/home_screen.dart';
import 'views/reports/create_report_screen.dart';

import 'views/splash/splash_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/profile/edit_profile_screen.dart';
import 'views/admin/category_management_screen.dart';
import 'views/admin/add_edit_category_screen.dart';
import 'views/admin/admin_report_list_screen.dart';

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
        title: 'ZONARA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/manage-categories': (context) => const CategoryManagementScreen(),
          '/manage-categories/add': (context) => const AddEditCategoryScreen(),
          '/manage-reports': (context) => const AdminReportListScreen(),
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
