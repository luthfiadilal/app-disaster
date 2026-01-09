import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(-6.2088, 106.8456); // Default: Jakarta
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      }
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _hasLocation = true;
    });

    // Move map to current location
    _mapController.move(_currentPosition, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster GIS'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              accountName: Text(user?.fullName ?? 'User'),
              accountEmail: Text(user?.email ?? 'email@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            if (user?.role == 'admin') ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text('Admin Menu', style: TextStyle(color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Manajemen Laporan'),
                onTap: () {
                  // Navigate to Manajemen Laporan
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Manajemen Kategori'),
                onTap: () {
                  // Navigate to Manajemen Kategori
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Manajemen Region'),
                onTap: () {
                  // Navigate to Manajemen Region
                  Navigator.pop(context);
                },
              ),
            ] else ...[
              // User Role
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Riwayat Laporan'),
                onTap: () {
                  // Navigate to Riwayat Laporan
                  Navigator.pop(context);
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                // Navigate to Profile
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Logout'),
              onTap: () {
                authProvider.logout();
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: _currentPosition, initialZoom: 13.0),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app_disaster_gis',
          ),
          if (_hasLocation)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition,
                  width: 80,
                  height: 80,
                  child: const Column(
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 40),
                      Text(
                        'You are here',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _determinePosition,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
