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
// import 'package:intl/intl.dart';
import '../../views/widgets/disaster_report_card.dart';
import '../../views/reports/user_reports_screen.dart';
// import 'disaster_detail_screen.dart';

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

  // Disaster report markers from selected region
  List<DisasterReport> _disasterReports = [];
  bool _showDisasterMarkers = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchRisks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set token from AuthProvider to local ApiService instance
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _apiService.setToken(authProvider.token);
    }
  }

  Future<void> _fetchRisks() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  void _onPolygonTap(RegionRisk risk) async {
    // Fetch disaster reports for this region
    try {
      final reports = await _apiService.getReportsByRegion(risk.regionId);

      // Filter hanya yang terverifikasi
      final verifiedReports = reports
          .where((report) => report.status == 'terverifikasi')
          .toList();

      if (mounted) {
        setState(() {
          _disasterReports = verifiedReports;
          _showDisasterMarkers = true;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports for region: $e');
    }

    // Show bottom sheet
    if (mounted) {
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    // Cek apakah user sudah login
    if (user == null) {
      // Tampilkan dialog jika belum login
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Login Diperlukan'),
            content: const Text(
              'Anda harus login terlebih dahulu untuk membuat laporan bencana.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Tutup dialog
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Tutup dialog
                  Navigator.pushNamed(context, '/login'); // Ke halaman login
                },
                child: const Text('Login'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Jika sudah login, lanjutkan proses picking location
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
                  // Tampilkan header berbeda untuk user yang belum login
                  if (user != null)
                    UserAccountsDrawerHeader(
                      decoration: const BoxDecoration(color: Colors.blueAccent),
                      accountName: Text(user.fullName),
                      accountEmail: Text(user.email),
                      currentAccountPicture: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage:
                            user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? Text(
                                user.fullName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.blueAccent,
                                ),
                              )
                            : null,
                      ),
                    )
                  else
                    DrawerHeader(
                      decoration: const BoxDecoration(color: Colors.blueAccent),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.account_circle,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'ZONARA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Menu Home - selalu ditampilkan
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Home'),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                    },
                  ),

                  // Jika belum login, hanya tampilkan menu Login
                  if (user == null)
                    ListTile(
                      leading: const Icon(Icons.login),
                      title: const Text('Login'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/login');
                      },
                    ),

                  // Menu untuk user yang sudah login
                  if (user != null) ...[
                    if (user.role != 'admin')
                      ListTile(
                        leading: const Icon(Icons.assignment),
                        title: const Text('Laporan Saya'),
                        onTap: () {
                          Navigator.pop(context); // Close drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserReportsScreen(apiService: _apiService),
                            ),
                          );
                        },
                      ),
                    if (user.role == 'admin') ...[
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
                        leading: const Icon(
                          Icons.category,
                          color: Colors.orange,
                        ),
                        title: const Text('Manajemen Kategori'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/manage-categories');
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
                        ).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                    ),
                  ],
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

              // Disaster Report Markers (White tiles)
              if (_showDisasterMarkers)
                MarkerLayer(
                  markers: _disasterReports.map((report) {
                    // Parse latitude and longitude
                    double? lat = double.tryParse(report.latitude.toString());
                    double? lng = double.tryParse(report.longitude.toString());

                    if (lat != null && lng != null) {
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            // Show disaster report details
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(report.title),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Event: ${report.eventName ?? "-"}'),
                                      const SizedBox(height: 8),
                                      Text('Severity: ${report.severity}'),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Description: ${report.description}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Location: ${report.address ?? "-"}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Status: ${report.status}'),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.red, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  spreadRadius: 2,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.warning,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }
                    // Return empty marker if coordinates are invalid
                    return Marker(
                      point: const LatLng(0, 0),
                      width: 0,
                      height: 0,
                      child: const SizedBox.shrink(),
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
      // SECTION FAB
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
  List<DisasterReport> _filteredReports = [];
  bool _loading = true;

  // Filter states
  String? _selectedDistrict;
  String? _selectedVillage;
  int? _selectedCategory;
  String? _selectedSeverity;

  // Filter options
  List<String> _districts = [];
  List<String> _villages = [];
  List<int> _categoryIds = [];
  List<String> _severities = [];

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
        // Filter hanya yang terverifikasi
        final verifiedReports = reports
            .where((report) => report.status == 'terverifikasi')
            .toList();

        setState(() {
          _reports = verifiedReports;
          _filteredReports = verifiedReports;
          _loading = false;
          _buildFilterOptions();
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports by region: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _buildFilterOptions() {
    // Extract unique values for filters
    _districts =
        _reports
            .map((r) => r.district)
            .where((d) => d != null && d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _villages =
        _reports
            .map((r) => r.village)
            .where((v) => v != null && v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _categoryIds = _reports.map((r) => r.categoryId).toSet().toList()..sort();

    _severities =
        _reports
            .map((r) => r.severity)
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _reports.where((report) {
        bool matchesDistrict =
            _selectedDistrict == null || report.district == _selectedDistrict;
        bool matchesVillage =
            _selectedVillage == null || report.village == _selectedVillage;
        bool matchesCategory =
            _selectedCategory == null || report.categoryId == _selectedCategory;
        bool matchesSeverity =
            _selectedSeverity == null || report.severity == _selectedSeverity;

        return matchesDistrict &&
            matchesVillage &&
            matchesCategory &&
            matchesSeverity;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedDistrict = null;
      _selectedVillage = null;
      _selectedCategory = null;
      _selectedSeverity = null;
      _filteredReports = _reports;
    });
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Laporan di ${widget.regionName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_loading && _reports.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter Section
          if (!_loading && _reports.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // District Filter
                  if (_districts.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: const Text('Kecamatan'),
                        value: _selectedDistrict,
                        underline: const SizedBox(),
                        items: _districts.map((district) {
                          return DropdownMenuItem(
                            value: district,
                            child: Text(
                              district,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedDistrict = value);
                          _applyFilters();
                        },
                      ),
                    ),

                  // Village Filter
                  if (_villages.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: const Text('Kelurahan'),
                        value: _selectedVillage,
                        underline: const SizedBox(),
                        items: _villages.map((village) {
                          return DropdownMenuItem(
                            value: village,
                            child: Text(
                              village,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedVillage = value);
                          _applyFilters();
                        },
                      ),
                    ),

                  // Category Filter
                  if (_categoryIds.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        hint: const Text('Kategori'),
                        value: _selectedCategory,
                        underline: const SizedBox(),
                        items: _categoryIds.map((catId) {
                          // Find category name from first report with this ID
                          final categoryName =
                              _reports
                                  .firstWhere((r) => r.categoryId == catId)
                                  .category
                                  ?.name ??
                              'Category $catId';
                          return DropdownMenuItem(
                            value: catId,
                            child: Text(
                              categoryName,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                          _applyFilters();
                        },
                      ),
                    ),

                  // Severity Filter
                  if (_severities.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        hint: const Text('Severity'),
                        value: _selectedSeverity,
                        underline: const SizedBox(),
                        items: _severities.map((severity) {
                          return DropdownMenuItem(
                            value: severity,
                            child: Text(
                              severity,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedSeverity = value);
                          _applyFilters();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Menampilkan ${_filteredReports.length} dari ${_reports.length} laporan',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(),
          ],

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                ? const Center(child: Text('Tidak ada laporan di area ini.'))
                : _filteredReports.isEmpty
                ? const Center(
                    child: Text('Tidak ada laporan yang sesuai filter.'),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _filteredReports.length,
                    itemBuilder: (context, index) {
                      final report = _filteredReports[index];
                      return DisasterReportCard(report: report);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
