import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/disaster_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AdminReportListScreen extends StatefulWidget {
  const AdminReportListScreen({super.key});

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  final ApiService _apiService = ApiService();

  // Data
  List<DisasterReport> _allReports = [];
  List<DisasterReport> _filteredReports = [];
  bool _isLoading = true;

  // Filters
  String _selectedStatus = 'Semua';
  String _selectedSeverity = 'Semua';

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
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _apiService.setToken(authProvider.token);
      final reports = await _apiService.getAllDisasterReports();
      if (mounted) {
        setState(() {
          _allReports = reports;
          _isLoading = false;
        });
        _applyFilters();
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

  void _applyFilters() {
    setState(() {
      _filteredReports = _allReports.where((report) {
        final statusMatch =
            _selectedStatus == 'Semua' ||
            report.status.toLowerCase() == _selectedStatus.toLowerCase();

        final severityMatch =
            _selectedSeverity == 'Semua' ||
            report.severity.toLowerCase() == _selectedSeverity.toLowerCase();

        return statusMatch && severityMatch;
      }).toList();
    });
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
          // Filter Section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Laporan',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                        ),
                        items: _statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              _formatLabel(status),
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Severity Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSeverity,
                        decoration: const InputDecoration(
                          labelText: 'Tingkat',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                        ),
                        items: _severityOptions.map((severity) {
                          return DropdownMenuItem(
                            value: severity,
                            child: Text(
                              _formatLabel(severity),
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedSeverity = value;
                            });
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada laporan sesuai filter',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchReports,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredReports.length,
                      itemBuilder: (context, index) {
                        final report = _filteredReports[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildStatusBadge(report.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Severity Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(
                                      report.severity,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Tingkat: ${report.severity.toUpperCase()}',
                                    style: TextStyle(
                                      color: _getSeverityColor(report.severity),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  report.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      report.reporter?.fullName ?? 'Unknown',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy HH:mm',
                                      ).format(report.createdAt),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (report.images.isNotEmpty)
                                  Container(
                                    height: 100,
                                    margin: const EdgeInsets.only(top: 8),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: report.images.length,
                                      itemBuilder: (context, imgIndex) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              report.images[imgIndex],
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    width: 100,
                                                    height: 100,
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.image_not_supported,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
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

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'total':
        return Colors.purple;
      case 'berat':
        return Colors.red;
      case 'sedang':
        return Colors.orange;
      case 'ringan':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'selesai':
        color = Colors.green;
        break;
      case 'terverifikasi':
        color = Colors.blue;
        break;
      case 'dalam_pengerjaan':
        color = Colors.orange;
        break;
      case 'ditolak':
        color = Colors.red;
        break;
      default: // menunggu
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
