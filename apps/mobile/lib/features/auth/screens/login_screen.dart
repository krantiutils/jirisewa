import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/phone_validation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showOtp = false;
  bool _loading = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (!isValidNepalPhone(phone)) {
      setState(() => _error = 'Enter a valid Nepal mobile number (98XXXXXXXX)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _supabase.auth.signInWithOtp(phone: toE164(phone));
      setState(() {
        _showOtp = true;
        _loading = false;
      });
      _startResendTimer();
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to send OTP. Please try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _supabase.auth.verifyOTP(
        phone: toE164(_phoneController.text.trim()),
        token: otp,
        type: OtpType.sms,
      );

      if (!mounted) return;

      if (response.user != null) {
        // SessionService picks up the auth state change via onAuthStateChange,
        // fetches the profile, then notifies listeners. GoRouter's
        // refreshListenable triggers redirect: → /register or /home.
        // No manual navigation needed here.
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = 'Invalid OTP. Please try again.';
        });
      }
    } on AuthException catch (_) {
      setState(() {
        _loading = false;
        _error = 'Invalid OTP. Please try again.';
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Invalid OTP. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _showOtp ? _buildOtpForm() : _buildPhoneForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Login to JiriSewa',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your phone number to get started',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 32),
        Text(
          'Phone Number',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '+977',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  hintText: '98XXXXXXXX',
                ),
                onSubmitted: (_) => _sendOtp(),
                autofocus: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your 10-digit Nepal mobile number',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _sendOtp,
          child: Text(_loading ? 'Sending...' : 'Send OTP'),
        ),
      ],
    );
  }

  Widget _buildOtpForm() {
    final phone = normalizePhone(_phoneController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify OTP',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the 6-digit code sent to +977$phone',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 12,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            hintText: '------',
          ),
          onSubmitted: (_) => _verifyOtp(),
          autofocus: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _verifyOtp,
          child: Text(_loading ? 'Verifying...' : 'Verify'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _showOtp = false;
                  _otpController.clear();
                  _error = null;
                });
              },
              child: Text(
                'Change phone number',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: _resendCooldown > 0 ? null : _sendOtp,
              child: Text(
                _resendCooldown > 0
                    ? 'Resend in ${_resendCooldown}s'
                    : 'Resend OTP',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
