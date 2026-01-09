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
  bool _isPickingLocation = false;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

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

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _hasLocation = true;
    });

    _mapController.move(_currentPosition, 15.0);
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
    });
  }

  void _startPickingLocation() {
    setState(() {
      _isPickingLocation = true;
      _isFabExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap on map to select location')),
    );
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isPickingLocation) {
      setState(() {
        _isPickingLocation = false;
      });
      // Navigate to Create Report Screen
      Navigator.pushNamed(context, '/create-report', arguments: point);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPickingLocation ? 'Pick Location' : 'ZONARA'),
        backgroundColor: _isPickingLocation ? Colors.green : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(
          color: _isPickingLocation ? Colors.white : Colors.black87,
        ),
        titleTextStyle: TextStyle(
          color: _isPickingLocation ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        leading: _isPickingLocation
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isPickingLocation = false;
                  });
                },
              )
            : null,
      ),
      drawer: _isPickingLocation
          ? null
          : Drawer(
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
                      child: Text(
                        'Admin Menu',
                        style: TextStyle(color: Colors.grey),
                      ),
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 13.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
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
                          Icon(Icons.location_on, color: Colors.blue, size: 40),
                          Text(
                            'My Loc',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_isPickingLocation)
            Positioned(
              top: 10,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap on the map to select report location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isPickingLocation
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isFabExpanded) ...[
                  FloatingActionButton.small(
                    heroTag: 'loc_btn',
                    onPressed: _determinePosition,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'report_btn',
                    onPressed: _startPickingLocation,
                    backgroundColor: Colors.red,
                    icon: const Icon(Icons.add_alert, color: Colors.white),
                    label: const Text(
                      'Buat Laporan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: 'main_fab',
                  onPressed: _toggleFab,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(
                    _isFabExpanded ? Icons.close : Icons.add,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
