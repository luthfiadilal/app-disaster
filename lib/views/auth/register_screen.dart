import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../components/custom_button.dart';
import '../components/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String _selectedGender = 'L'; // Default value

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final userModel = UserModel(
        username: _usernameController.text,
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
        gender: _selectedGender,
        address: _addressController.text,
        city: _cityController.text,
      );

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      try {
        final success = await authProvider.register(userModel);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful!')),
          );
          Navigator.pop(context); // Go back to Login
        } else if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Registration Failed')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  label: 'Username',
                  hint: 'Enter username',
                  controller: _usernameController,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter username' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Full Name',
                  hint: 'Enter full name',
                  controller: _fullNameController,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter full name' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Email',
                  hint: 'Enter email',
                  keyboardType: TextInputType.emailAddress,
                  controller: _emailController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter password',
                  obscureText: true,
                  controller: _passwordController,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter password' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Phone Number',
                  hint: 'Enter phone number',
                  keyboardType: TextInputType.phone,
                  controller: _phoneController,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter phone number' : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gender',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Male'),
                        value: 'L',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Female'),
                        value: 'P',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Address',
                  hint: 'Enter address',
                  controller: _addressController,
                  maxLines: 3,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter address' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'City',
                  hint: 'Enter city',
                  controller: _cityController,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter city' : null,
                ),
                const SizedBox(height: 32),
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return CustomButton(
                      text: 'Register',
                      onPressed: _handleRegister,
                      isLoading: auth.isLoading,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
