import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/disaster_report_model.dart';
import '../../models/disaster_category_model.dart';
import '../../models/region_risk_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../widgets/disaster_report_card.dart';

class AdminReportListScreen extends StatefulWidget {
  const AdminReportListScreen({super.key});

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  final ApiService _apiService = ApiService();

  // Data
  List<DisasterReport> _reports = [];
  bool _isLoading = true;

  // Filter Data Sources
  List<DisasterCategory> _categories = [];
  List<RegionRisk> _regions =
      []; // We use RegionRisk as it contains region info

  // Selected Filters
  String _selectedStatus = 'Semua';
  String _selectedSeverity = 'Semua';
  int? _selectedCategoryId; // null means 'Semua'
  int? _selectedRegionId; // null means 'Semua'

  final List<String> _statusOptions = [
    'Semua',
    'menunggu',
    'terverifikasi',
    'dalam_pengerjaan',
    'selesai',
    'ditolak',
  ];

  final List<String> _severityOptions = [
    'Semua',
    'ringan',
    'sedang',
    'berat',
    'total',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService.setToken(authProvider.token);

    try {
      await Future.wait([_fetchCategories(), _fetchRegions(), _fetchReports()]);
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _fetchRegions() async {
    try {
      final regions = await _apiService.getRegionRisks();
      if (mounted) {
        setState(() {
          _regions = regions;
        });
      }
    } catch (e) {
      debugPrint('Error fetching regions: $e');
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _apiService.getAllDisasterReports(
        categoryId: _selectedCategoryId,
        severity: _selectedSeverity == 'Semua' ? null : _selectedSeverity,
        status: _selectedStatus == 'Semua' ? null : _selectedStatus,
        regionId: _selectedRegionId,
      );
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'Semua' ||
      _selectedSeverity != 'Semua' ||
      _selectedCategoryId != null ||
      _selectedRegionId != null;

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'Semua';
      _selectedSeverity = 'Semua';
      _selectedCategoryId = null;
      _selectedRegionId = null;
    });
    _fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Laporan'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReports),
        ],
      ),
      body: Column(
        children: [
          // Filter Section (Modern)
          _buildFilterBar(),

          // List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada laporan sesuai filter',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (_hasActiveFilters)
                          TextButton(
                            onPressed: _resetFilters,
                            child: const Text('Reset Filter'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchReports,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        return DisasterReportCard(
                          report: _reports[index],
                          showStatus: true,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Filter Button
          InkWell(
            onTap: _showFilterModal,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _hasActiveFilters ? Colors.blueAccent : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hasActiveFilters
                      ? Colors.blueAccent
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: _hasActiveFilters ? Colors.white : Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: TextStyle(
                      color: _hasActiveFilters
                          ? Colors.white
                          : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(), // Dot indicator
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Active Filters Horizontal List
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!_hasActiveFilters)
                    Text(
                      'Semua Laporan',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  if (_selectedStatus != 'Semua')
                    _buildFilterChip(
                      'Status: ${_formatLabel(_selectedStatus)}',
                      () {
                        setState(() => _selectedStatus = 'Semua');
                        _fetchReports();
                      },
                    ),
                  if (_selectedSeverity != 'Semua')
                    _buildFilterChip(
                      'Tingkat: ${_formatLabel(_selectedSeverity)}',
                      () {
                        setState(() => _selectedSeverity = 'Semua');
                        _fetchReports();
                      },
                    ),
                  if (_selectedCategoryId != null && _categories.isNotEmpty)
                    _buildFilterChip(
                      'Kategori: ${_categories.firstWhere(
                        (e) => e.id == _selectedCategoryId,
                        orElse: () => DisasterCategory(id: 0, name: 'Unknown', iconUrl: ''),
                      ).name}',
                      () {
                        setState(() => _selectedCategoryId = null);
                        _fetchReports();
                      },
                    ),
                  if (_selectedRegionId != null && _regions.isNotEmpty)
                    _buildFilterChip(
                      'Region: ${_regions.firstWhere(
                        (e) => e.regionId == _selectedRegionId,
                        orElse: () => RegionRisk(regionId: 0, regionName: 'Unknown', riskScore: 0, riskStatus: '', riskColor: 'gray', geom: []),
                      ).regionName}',
                      () {
                        setState(() => _selectedRegionId = null);
                        _fetchReports();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Local state for the modal
        String tempStatus = _selectedStatus;
        String tempSeverity = _selectedSeverity;
        int? tempCategoryId = _selectedCategoryId;
        int? tempRegionId = _selectedRegionId;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Laporan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempStatus = 'Semua';
                                tempSeverity = 'Semua';
                                tempCategoryId = null;
                                tempRegionId = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Form
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildSectionLabel('Status'),
                          _buildDropdown(
                            label: 'Pilih Status',
                            value: tempStatus,
                            items: _statusOptions,
                            onChanged: (val) {
                              setModalState(() => tempStatus = val!);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Tingkat Keparahan'),
                          _buildDropdown(
                            label: 'Pilih Tingkat',
                            value: tempSeverity,
                            items: _severityOptions,
                            onChanged: (val) {
                              setModalState(() => tempSeverity = val!);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Kategori Bencana'),
                          DropdownButtonFormField<int?>(
                            value: tempCategoryId,
                            decoration: _inputDecoration('Pilih Kategori'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua'),
                              ),
                              ..._categories.map((cat) {
                                return DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Text(cat.name),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setModalState(() => tempCategoryId = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('Wilayah (Region)'),
                          DropdownButtonFormField<int?>(
                            value: tempRegionId,
                            decoration: _inputDecoration('Pilih Wilayah'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Semua'),
                              ),
                              ..._regions.map((reg) {
                                return DropdownMenuItem<int?>(
                                  value: reg.regionId,
                                  child: Text(reg.regionName),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setModalState(() => tempRegionId = val);
                            },
                          ),
                          const SizedBox(height: 100), // Space for button
                        ],
                      ),
                    ),
                    // Apply Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatus = tempStatus;
                              _selectedSeverity = tempSeverity;
                              _selectedCategoryId = tempCategoryId;
                              _selectedRegionId = tempRegionId;
                            });
                            Navigator.pop(context);
                            _fetchReports();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Terapkan Filter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      isDense: true,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(label),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            _formatLabel(item),
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _formatLabel(String value) {
    if (value == 'Semua') return value;
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str[0].toUpperCase() + str.substring(1))
        .join(' ');
  }
}
