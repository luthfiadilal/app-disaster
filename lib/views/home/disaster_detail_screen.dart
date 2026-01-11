import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/disaster_report_model.dart';

class DisasterDetailScreen extends StatelessWidget {
  final DisasterReport report;

  const DisasterDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Immersive Image Header
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            flexibleSpace: FlexibleSpaceBar(
              background: report.images.isNotEmpty
                  ? Image.network(
                      report.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[200]),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
            // Gradient Overlay for readability if we put text on image,
            // but for minimalist white theme, standard is fine or just back button.
          ),

          // 2. Content Body
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row
                    Row(
                      children: [
                        _buildBadge(
                          text: report.category?.name ?? 'Umum',
                          color: Colors.blue[50]!,
                          textColor: Colors.blue[800]!,
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          text: report.severity.toUpperCase(),
                          color: _getSeverityColor(
                            report.severity,
                          ).withOpacity(0.1),
                          textColor: _getSeverityColor(report.severity),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(report.incidentTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        letterSpacing: -0.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reporter Info (Mini Profile)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: report.reporter?.avatarUrl != null
                              ? NetworkImage(report.reporter!.avatarUrl!)
                              : null,
                          child: report.reporter?.avatarUrl == null
                              ? Text(
                                  (report.reporter?.fullName ?? 'U')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.reporter?.fullName ?? 'Anonymous',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'Pelapor',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 24),

                    // Description Section
                    _buildSectionTitle('Deskripsi'),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Impact Section (if exists)
                    if (report.impactDetail.isNotEmpty) ...[
                      _buildSectionTitle('Dampak'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[100]!),
                        ),
                        child: Text(
                          report.impactDetail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[900],
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Location Section
                    _buildSectionTitle('Lokasi'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          _buildLocationRow(Icons.location_on, report.address),
                          const SizedBox(height: 12),
                          _buildLocationRow(
                            Icons.home_work,
                            '${report.village}, ${report.district}',
                          ),
                          const SizedBox(height: 12),
                          _buildLocationRow(
                            Icons.map,
                            '${report.latitude}, ${report.longitude}',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge({
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'ringan':
        return Colors.green;
      case 'sedang':
        return Colors.orange;
      case 'berat':
      case 'total':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
