import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  Future<void> _handleRegister() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    bool hasError = false;

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address');
      hasError = true;
    } else if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'Please enter a password');
      hasError = true;
    } else if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      hasError = true;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password');
      hasError = true;
    } else if (confirmPassword != password) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isLoading = true);
    try {
      final response = await _authService.signUp(email, password);

      if (response.user != null && response.user!.identities != null && response.user!.identities!.isEmpty) {
        throw Exception('already registered');
      }
      
      if (mounted) {
        if (response.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!'), backgroundColor: AppColors.accentGreen),
          );
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainScreen()), (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code sent to your email!'), backgroundColor: AppColors.accentGreen),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(email: email),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errorStr = e.toString();
          if (errorStr.contains('already registered')) {
            _emailError = 'This email is already in use.';
          } else if (errorStr.contains('unexpected_failure')) {
            _emailError = 'Supabase Email Limit Reached (3 per hour). Try again later.';
          } else {
            _emailError = 'Registration failed: ${errorStr.split(']').last.trim()}';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: const BackButton(color: AppColors.secondary)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create Account', style: TextStyle(color: AppColors.secondary, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Start your CarDecide journey', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 40),
              
              _buildLabel('EMAIL ADDRESS'),
              _buildTextField(_emailController, 'amir@example.com', Icons.email_outlined, false, errorText: _emailError),
              const SizedBox(height: 24),
              
              _buildLabel('PASSWORD'),
              _buildTextField(_passwordController, '********', Icons.lock_outline, true, errorText: _passwordError),
              const SizedBox(height: 24),

              _buildLabel('CONFIRM PASSWORD'),
              _buildTextField(_confirmPasswordController, '********', Icons.lock_outline, true, errorText: _confirmPasswordError),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign Up', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isPassword, {String? errorText}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      decoration: InputDecoration(
        errorText: errorText,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}
