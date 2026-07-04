import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/platform_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/responsive/media_query_helper.dart';
import '../../common/buttons/app_button.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/main/main_view.dart';
import 'email_login_view.dart';

// ============================================================================
// OTP VERIFICATION VIEW
// Displays 6 digit OTP boxes backed by a single hidden TextField.
// Includes a 30-second resend cooldown timer.
// ============================================================================

class OtpVerificationView extends StatefulWidget {
  final String email;
  final bool isRegister;

  const OtpVerificationView({
    super.key,
    required this.email,
    this.isRegister = false,
  });

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _vm = AuthViewModel();

  bool _isVerifying = false;
  String? _errorMessage;

  // ── Resend cooldown ───────────────────────────────────────────────────────
  bool _canResend = false;
  int _resendCooldown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    _otpController.addListener(_onOtpChanged);
    _otpFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    _otpFocusNode.removeListener(_onFocusChanged);
    _otpController.dispose();
    _otpFocusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onOtpChanged() {
    setState(() {
      if (_errorMessage != null) _errorMessage = null;
    });
    if (_otpController.text.length == 6) _verify();
  }

  void _startResendCooldown() {
    _canResend = false;
    _resendCooldown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    final result = await _vm.sendOtp(widget.email);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'OTP sent successfully.'),
        backgroundColor: result.shouldOpenOtpVerification
            ? AppColors.lightSuccess
            : AppColors.lightError,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _otpController.clear();
    setState(() => _errorMessage = null);
    _startResendCooldown();
  }

  Future<void> _verify() async {
    final code = _otpController.text;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Enter all 6 digits to continue.');
      return;
    }
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = widget.isRegister
        ? await _vm.verifyRegister(email: widget.email, code: code)
        : await _vm.verifyOtp(email: widget.email, code: code);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Verification successful.'),
          backgroundColor: AppColors.lightSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.isRegister
              ? const EmailLoginView()
              : const MainView(),
        ),
      );
    } else {
      final errorMsg = result.message ?? 'Invalid code. Please try again.';
      setState(() {
        _isVerifying = false;
        _errorMessage = errorMsg;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.lightError,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _otpController.clear();
      _otpFocusNode.requestFocus();
    }
  }

  // ── Mask email for display: a**@domain.com ────────────────────────────────
  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryHelper.init(context);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            PlatformHelper.isIOS
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_back_rounded,
          ),
          color: AppColors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQueryHelper.scaleWidth(24),
              vertical: MediaQueryHelper.scaleHeight(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: MediaQueryHelper.scaleHeight(8)),

                // ── Title ──────────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Verify your email',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.lightPrimary,
                    ),
                  ),
                ),

                SizedBox(height: MediaQueryHelper.scaleHeight(10)),

                // ── Subtitle ───────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter the 6-digit code sent to\n${_maskedEmail(widget.email)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                ),

                SizedBox(height: MediaQueryHelper.scaleHeight(48)),

                // ── OTP input area ─────────────────────────────────────────
                _buildOtpInput(),

                // ── Error message ──────────────────────────────────────────
                if (_errorMessage != null) ...[
                  SizedBox(height: MediaQueryHelper.scaleHeight(12)),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.lightError,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                SizedBox(height: MediaQueryHelper.scaleHeight(48)),

                // ── Verify button ──────────────────────────────────────────
                AppButton.primary(
                  text: 'Verify OTP',
                  onPressed: _isVerifying ? null : _verify,
                  isLoading: _isVerifying,
                  isFullWidth: true,
                ),

                SizedBox(height: MediaQueryHelper.scaleHeight(24)),

                // ── Resend ─────────────────────────────────────────────────
                _buildResendRow(),

                SizedBox(height: MediaQueryHelper.scaleHeight(24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP INPUT ─────────────────────────────────────────────────────────────
  // Single hidden TextField drives all 6 visual boxes.

  Widget _buildOtpInput() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Visual boxes (bottom of stack)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(6, _buildOtpBox),
        ),

        // Hidden real input — covers the entire row to reliably catch taps
        Positioned.fill(
          child: TextField(
            controller: _otpController,
            focusNode: _otpFocusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            showCursor: false,
            enableInteractiveSelection: false,
            style: const TextStyle(color: Colors.transparent, fontSize: 1), // Invisible text
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    final text = _otpController.text;
    final hasChar = index < text.length;
    final isActive = index == text.length && _otpFocusNode.hasFocus;
    final hasError = _errorMessage != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(
        horizontal: MediaQueryHelper.scaleWidth(5),
      ),
      width: MediaQueryHelper.scaleWidth(42),
      height: MediaQueryHelper.scaleWidth(50),
      decoration: BoxDecoration(
        color: hasChar ? AppColors.lightSurface : AppColors.lightBackground,
        border: Border.all(
          color: hasError
              ? AppColors.lightError
              : isActive
                  ? AppColors.lightPrimary
                  : AppColors.lightDivider,
          width: isActive || hasError ? 2.0 : 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        hasChar ? text[index] : '',
        style: AppTextStyles.heading2.copyWith(
          color: AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  // ── RESEND ROW ────────────────────────────────────────────────────────────

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive it? ",
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.lightTextSecondary,
          ),
        ),
        _canResend
            ? GestureDetector(
                onTap: _resendOtp,
                child: Text(
                  'Resend OTP',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.lightPrimary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.lightPrimary,
                  ),
                ),
              )
            : Text(
                'Resend in ${_resendCooldown}s',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.lightDivider,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ],
    );
  }
}
