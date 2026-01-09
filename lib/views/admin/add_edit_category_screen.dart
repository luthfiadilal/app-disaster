import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/disaster_category_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../components/custom_button.dart';
import '../components/custom_text_field.dart';

class AddEditCategoryScreen extends StatefulWidget {
  const AddEditCategoryScreen({super.key});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  DisasterCategory? _categoryToEdit;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DisasterCategory) {
      _categoryToEdit = args;
      _nameController = TextEditingController(text: _categoryToEdit!.name);
    } else {
      _nameController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Get token
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _apiService.setToken(authProvider.token);

      try {
        bool success;
        if (_categoryToEdit != null) {
          // Update
          success = await _apiService.updateCategory(
            _categoryToEdit!.id,
            _nameController.text,
            null, // No icon update from UI
          );
        } else {
          // Create
          success = await _apiService.createCategory(
            _nameController.text,
            null, // No icon creation from UI
          );
        }

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Failed to save')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _categoryToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Category' : 'Add Category')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Category Name',
                hint: 'Enter category name',
                prefixIcon: const Icon(Icons.category),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              CustomButton(
                text: isEditing ? 'Update Category' : 'Create Category',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
