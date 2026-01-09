import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/disaster_category_model.dart';
import '../components/custom_button.dart';
import '../components/custom_text_field.dart';

class CreateReportScreen extends StatefulWidget {
  final LatLng point;

  const CreateReportScreen({super.key, required this.point});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _impactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  DateTime _incidentTime = DateTime.now();
  String _severity = 'sedang'; // ringan, sedang, berat
  int? _selectedCategoryId;
  List<DisasterCategory> _categories = [];
  bool _isLoading = false;
  bool _isFetchingAddress = true;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _getAddressFromLatLng();
  }

  Future<void> _fetchCategories() async {
    // Get token from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService.setToken(authProvider.token);

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.point.latitude,
        widget.point.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressController.text = '${place.street}';
          _villageController.text = '${place.subLocality}';
          _districtController.text = '${place.locality}';
          _isFetchingAddress = false;
        });
      } else {
        setState(() => _isFetchingAddress = false);
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      setState(() => _isFetchingAddress = false);
    }
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      setState(() => _isLoading = true);

      Map<String, dynamic> data = {
        "category_id": _selectedCategoryId,
        "title": _titleController.text,
        "event_name": _eventNameController.text,
        "description": _descController.text,
        "impact_detail": _impactController.text,
        "severity": _severity,
        "latitude": widget.point.latitude,
        "longitude": widget.point.longitude,
        "address": _addressController.text,
        "village": _villageController.text,
        "district": _districtController.text,
        "incident_time": DateFormat(
          "yyyy-MM-dd HH:mm:ss",
        ).format(_incidentTime),
      };

      try {
        List<String> imagePaths = _selectedImages.map((e) => e.path).toList();
        final success = await _apiService.createDisasterReport(
          data,
          imagePaths,
        );

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report created successfully!')),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Laporan Bencana')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coordinates Display
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey[200],
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Lat: ${widget.point.latitude}'),
                    Text('Lng: ${widget.point.longitude}'),
                    if (_isFetchingAddress) Text('Fetching Address...'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _titleController,
                label: 'Judul Laporan',
                hint: 'Masukkan judul laporan',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _eventNameController,
                label: 'Nama Kejadian (Event)',
                hint: 'Nama Kejadian (Event)',
              ),
              const SizedBox(height: 12),

              // Category Dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Kategori Bencana',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 12),

              // Severity Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tingkat Keparahan',
                  border: OutlineInputBorder(),
                ),
                value: _severity,
                items: ['ringan', 'sedang', 'berat', 'total'].map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _severity = val!),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                controller: _descController,
                label: 'Deskripsi',
                hint: 'Deskripsi',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _impactController,
                label: 'Detail Dampak',
                hint: 'Detail Dampak',
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Date Picker
              ListTile(
                title: Text(
                  "Waktu Kejadian: ${DateFormat('dd MMM yyyy HH:mm').format(_incidentTime)}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _incidentTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_incidentTime),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _incidentTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
              ),
              const Divider(),

              // Address Fields (Auto-filled but editable)
              CustomTextField(
                controller: _addressController,
                label: 'Alamat',
                hint: 'Alamat / Jalan',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _villageController,
                      label: 'Kelurahan',
                      hint: 'Kelurahan/Desa',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomTextField(
                      controller: _districtController,
                      label: 'Kecamatan',
                      hint: 'Kecamatan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Images
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tambah Foto'),
              ),
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.file(File(_selectedImages[index].path)),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomButton(
                      text: "Kirim Laporan",
                      onPressed: _submitReport,
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
