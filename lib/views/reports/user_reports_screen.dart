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
  late Future<List<DisasterReport>> _myReports;

  @override
  void initState() {
    super.initState();
    _myReports = widget.apiService.getMyReports();
  }

  Future<void> _refresh() async {
    setState(() {
      _myReports = widget.apiService.getMyReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DisasterReport>>(
          future: _myReports,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('Belum ada laporan yang Anda buat.'),
              );
            } else {
              final reports = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  return DisasterReportCard(
                    report: reports[index],
                    showStatus: true,
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
