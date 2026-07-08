import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _customerIdController = TextEditingController(text: 'cust_9988');
  bool _isLoading = false;

  void _login() {
    if (_customerIdController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // Simulate login delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        // In a real app, we would store the customer_id in a session manager
        // and navigate to the home shell.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainShell(customerId: _customerIdController.text.trim()),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.account_balance, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to\nACN Bank',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to access your accounts and cards.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _customerIdController,
                decoration: InputDecoration(
                  labelText: 'Customer ID',
                  hintText: 'Enter your customer ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Forgot Customer ID?',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
