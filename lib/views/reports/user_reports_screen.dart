import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/disaster_report_model.dart';
import '../widgets/disaster_report_card.dart';

class UserReportsScreen extends StatefulWidget {
  final ApiService apiService;

  const UserReportsScreen({super.key, required this.apiService});

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  List<DisasterReport> _allReports = [];
  List<DisasterReport> _filteredReports = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await widget.apiService.getMyReports();
      setState(() {
        _allReports = reports;
        _filteredReports = reports;
        _isLoading = false;
        _buildFilterOptions();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _buildFilterOptions() {
    // Extract unique values for filters
    _districts =
        _allReports
            .map((r) => r.district)
            .where((d) => d != null && d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _villages =
        _allReports
            .map((r) => r.village)
            .where((v) => v != null && v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    _categoryIds = _allReports.map((r) => r.categoryId).toSet().toList()
      ..sort();

    _severities =
        _allReports
            .map((r) => r.severity)
            .where((s) => s != null && s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _allReports.where((report) {
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
      _filteredReports = _allReports;
    });
  }

  Future<void> _refresh() async {
    await _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (!_isLoading && _allReports.isNotEmpty)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Reset'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $_errorMessage'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: Column(
                children: [
                  // Filter Section
                  if (_allReports.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // District Filter
                            if (_districts.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<int>(
                                  hint: const Text('Kategori'),
                                  value: _selectedCategory,
                                  underline: const SizedBox(),
                                  items: _categoryIds.map((catId) {
                                    final categoryName =
                                        _allReports
                                            .firstWhere(
                                              (r) => r.categoryId == catId,
                                            )
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Menampilkan ${_filteredReports.length} dari ${_allReports.length} laporan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],

                  // Reports List
                  Expanded(
                    child: _allReports.isEmpty
                        ? const Center(
                            child: Text('Belum ada laporan yang Anda buat.'),
                          )
                        : _filteredReports.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada laporan yang sesuai filter.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReports.length,
                            itemBuilder: (context, index) {
                              return DisasterReportCard(
                                report: _filteredReports[index],
                                showStatus: true,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
