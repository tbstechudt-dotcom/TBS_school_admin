import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Email service using Resend API (free: 100 emails/day)
/// Sign up at https://resend.com to get your API key
class EmailService {
  static const String _resendApiKey = 're_E8Z8FPSU_9bGefEwggWpxp7fe61hogkir';
  static const String _fromEmail = 'EduDesk <onboarding@resend.dev>';
  static const String _resendUrl = 'https://api.resend.com/emails';

  /// Send license key to the given email
  static Future<bool> sendLicenseKeyEmail({
    required String toEmail,
    required String licenseKey,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_resendUrl),
        headers: {
          'Authorization': 'Bearer $_resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': _fromEmail,
          'to': [toEmail],
          'subject': 'Your EduDesk License Key',
          'html': _buildEmailHtml(licenseKey, toEmail),
        }),
      );

      debugPrint('Email response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Email send error: $e');
      return false;
    }
  }

  static String _buildEmailHtml(String licenseKey, String email) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #f1f5ff; margin: 0; padding: 40px 20px; }
    .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 16px; padding: 40px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    .logo { text-align: center; margin-bottom: 24px; }
    .logo-icon { width: 60px; height: 60px; background: #E9EEFF; border-radius: 16px; display: inline-flex; align-items: center; justify-content: center; font-size: 28px; }
    h1 { color: #1E293B; text-align: center; font-size: 22px; margin: 0 0 8px; }
    .subtitle { color: #94A3B8; text-align: center; font-size: 14px; margin-bottom: 32px; }
    .key-box { background: #F1F5FF; border: 2px dashed #6C8EEF; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
    .key { font-size: 24px; font-weight: 700; color: #4A6CD4; letter-spacing: 3px; }
    .instructions { color: #64748B; font-size: 14px; line-height: 1.6; }
    .footer { text-align: center; color: #94A3B8; font-size: 12px; margin-top: 32px; padding-top: 20px; border-top: 1px solid #E2E8F0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo"><div class="logo-icon">🎓</div></div>
    <h1>Your EduDesk License Key</h1>
    <p class="subtitle">Use this key to activate your EduDesk application</p>

    <div class="key-box">
      <div class="key">$licenseKey</div>
    </div>

    <div class="instructions">
      <p><strong>How to activate:</strong></p>
      <ol>
        <li>Open the EduDesk application</li>
        <li>Enter the license key shown above</li>
        <li>Click "Activate"</li>
      </ol>
      <p>This key is single-use and tied to your email: <strong>$email</strong></p>
    </div>

    <div class="footer">
      <p>EduDesk - School Administration Platform</p>
      <p>If you didn't request this key, please ignore this email.</p>
    </div>
  </div>
</body>
</html>
''';
  }
}
