import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Implemented for compute

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/region_risk_model.dart';
import '../../models/disaster_report_model.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

// Helper class to transfer parsed data from Isolate
class RenderableRegion {
  final List<List<LatLng>> polygons;
  final String colorName;
  final RegionRisk originalRisk;

  RenderableRegion({
    required this.polygons,
    required this.colorName,
    required this.originalRisk,
  });
}

// Top-level function for Isolate
List<RenderableRegion> parseRegionsIso(List<RegionRisk> risks) {
  List<RenderableRegion> results = [];

  // Helper to parse GeoJSON inside Isolate
  List<List<LatLng>> parseGeomLocal(dynamic geom) {
    List<List<LatLng>> polygons = [];
    if (geom == null) return polygons;

    try {
      String type = geom['type'] ?? '';
      List coordinates = geom['coordinates'] ?? [];

      if (type == 'Polygon') {
        if (coordinates.isNotEmpty) {
          List outerRing = coordinates[0];
          List<LatLng> points = outerRing.map((c) {
            double d0 = c[0].toDouble();
            double d1 = c[1].toDouble();
            // Robust parsing: If 2nd coordinate (standard Lat) > 90, assume inverted [Lat, Long]
            if (d1.abs() > 90) {
              return LatLng(d0, d1);
            } else {
              return LatLng(d1, d0);
            }
          }).toList();
          polygons.add(points);
        }
      } else if (type == 'MultiPolygon') {
        for (var polygonCoords in coordinates) {
          if (polygonCoords.isNotEmpty) {
            List outerRing = polygonCoords[0];
            List<LatLng> points = outerRing.map((c) {
              double d0 = c[0].toDouble();
              double d1 = c[1].toDouble();
              // Robust parsing: If 2nd coordinate (standard Lat) > 90, assume inverted [Lat, Long]
              if (d1.abs() > 90) {
                return LatLng(d0, d1);
              } else {
                return LatLng(d1, d0);
              }
            }).toList();
            polygons.add(points);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing geom in isolate: $e');
    }
    return polygons;
  }

  for (var risk in risks) {
    final polys = parseGeomLocal(risk.geom);
    if (polys.isNotEmpty) {
      results.add(
        RenderableRegion(
          polygons: polys,
          colorName: risk.riskColor,
          originalRisk: risk,
        ),
      );
    }
  }
  return results;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(-6.2088, 106.8456); // Default: Jakarta
  bool _hasLocation = false;
  bool _isPickingLocation = false;
  bool _isFabExpanded = false;

  // Use RenderableRegion effectively caching the parsed polygons
  List<RenderableRegion> _renderableRegions = [];
  bool _isLoadingRisks = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchRisks();
  }

  Future<void> _fetchRisks() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _apiService.setToken(authProvider.token);

      try {
        final risks = await _apiService.getRegionRisks();

        // Offload heavy parsing to background isolate
        final parsedRegions = await compute(parseRegionsIso, risks);

        if (mounted) {
          setState(() {
            _renderableRegions = parsedRegions;
            _isLoadingRisks = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching risks: $e');
        if (mounted) setState(() => _isLoadingRisks = false);
      }
    });
  }

  Color _getColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red.withOpacity(0.4);
      case 'orange':
        return Colors.orange.withOpacity(0.4);
      case 'yellow':
        return Colors.yellow.withOpacity(0.4);
      case 'green':
        return Colors.green.withOpacity(0.4);
      default:
        return Colors.grey.withOpacity(0.4);
    }
  }

  Color _getBorderColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _onPolygonTap(RegionRisk risk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return RegionReportsSheet(
            regionId: risk.regionId,
            regionName: risk.regionName,
            scrollController: scrollController,
            apiService: _apiService,
          );
        },
      ),
    );
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
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
    } else {
      // Check if a polygon was tapped using parsed regions
      for (var renderRegion in _renderableRegions) {
        for (var polyPoints in renderRegion.polygons) {
          if (_isPointInPolygon(point, polyPoints)) {
            _onPolygonTap(renderRegion.originalRisk);
            return; // Found one, stop
          }
        }
      }
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
                      backgroundImage:
                          user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                          ? Text(
                              (user?.fullName ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.blueAccent,
                              ),
                            )
                          : null,
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
                        Navigator.pushNamed(context, '/manage-reports');
                      },
                    ),

                    ListTile(
                      leading: const Icon(Icons.category, color: Colors.orange),
                      title: const Text('Manajemen Kategori'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/manage-categories');
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
                        Navigator.pushNamed(
                          context,
                          '/profile',
                        ); // Redirect to profile/history if structured there
                      },
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
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
              // Optimized Polygon Layer
              if (!_isLoadingRisks)
                PolygonLayer(
                  polygons: _renderableRegions.expand((region) {
                    Color fillColor = _getColor(region.colorName);
                    Color borderColor = _getBorderColor(region.colorName);
                    return region.polygons.map(
                      (points) => Polygon(
                        points: points,
                        color: fillColor,
                        borderColor: borderColor,
                        borderStrokeWidth: 2,
                        isFilled: true,
                        label: region.originalRisk.regionName,
                        labelStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
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

class RegionReportsSheet extends StatefulWidget {
  final int regionId;
  final String regionName;
  final ScrollController scrollController;
  final ApiService apiService;

  const RegionReportsSheet({
    super.key,
    required this.regionId,
    required this.regionName,
    required this.scrollController,
    required this.apiService,
  });

  @override
  State<RegionReportsSheet> createState() => _RegionReportsSheetState();
}

class _RegionReportsSheetState extends State<RegionReportsSheet> {
  List<DisasterReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final reports = await widget.apiService.getReportsByRegion(
        widget.regionId,
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports by region: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Laporan di ${widget.regionName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                ? const Center(child: Text('Tidak ada laporan di area ini.'))
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: report.category?.iconUrl != null
                                ? NetworkImage(report.category!.iconUrl!)
                                : null,
                            child: report.category?.iconUrl == null
                                ? const Icon(Icons.warning)
                                : null,
                          ),
                          title: Text(report.title),
                          subtitle: Text(report.status),
                          trailing: Text(
                            DateFormat('dd MMM').format(report.incidentTime),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
