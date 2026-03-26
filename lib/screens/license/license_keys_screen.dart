import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class LicenseKeysScreen extends StatefulWidget {
  const LicenseKeysScreen({super.key});

  @override
  State<LicenseKeysScreen> createState() => _LicenseKeysScreenState();
}

class _LicenseKeysScreenState extends State<LicenseKeysScreen> {
  List<Map<String, dynamic>> _licenseKeys = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadLicenseKeys();
  }

  Future<void> _loadLicenseKeys() async {
    setState(() => _isLoading = true);
    final keys = await SupabaseService.getAllLicenseKeys();
    if (!mounted) return;
    setState(() {
      _licenseKeys = keys;
      _isLoading = false;
    });
  }

  Future<void> _showGenerateDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Generate License Key'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the recipient\'s email address. A license key will be generated and sent to them.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'school@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Generate & Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.trim().isNotEmpty) {
      await _generateAndSendKey(emailController.text.trim());
    }
    emailController.dispose();
  }

  Future<void> _generateAndSendKey(String email) async {
    setState(() => _isGenerating = true);

    final genResult = await SupabaseService.generateLicenseKey(email);

    if (!mounted) return;

    if (genResult['success'] != true) {
      setState(() => _isGenerating = false);
      _showSnackBar('Failed to generate key', isError: true);
      return;
    }

    _showSnackBar(
      'License key generated and sent to $email',
      duration: 3,
    );

    setState(() => _isGenerating = false);
    _loadLicenseKeys();
  }

  void _showSnackBar(String message, {bool isError = false, int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: Duration(seconds: duration),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'used':
        return AppColors.primary;
      case 'revoked':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle_outline;
      case 'used':
        return Icons.verified_rounded;
      case 'revoked':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License Keys',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate and manage application license keys',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _showGenerateDialog,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildStatCard(
                'Total Keys',
                _licenseKeys.length.toString(),
                Icons.key_rounded,
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Active',
                _licenseKeys.where((k) => k['status'] == 'active').length.toString(),
                Icons.check_circle_outline,
                AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Used',
                _licenseKeys.where((k) => k['status'] == 'used').length.toString(),
                Icons.verified_rounded,
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Revoked',
                _licenseKeys.where((k) => k['status'] == 'revoked').length.toString(),
                Icons.cancel_outlined,
                AppColors.error,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _licenseKeys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key_off_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No license keys yet',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Generate Key" to create one',
                            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppColors.surface),
                              columnSpacing: 24,
                              columns: const [
                                DataColumn(label: Text('License Key', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.w600))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                              ],
                              rows: _licenseKeys.map((key) {
                                final status = key['status'] ?? 'unknown';
                                final createdAt = key['created_at'] != null
                                    ? DateTime.tryParse(key['created_at'].toString())
                                    : null;

                                return DataRow(cells: [
                                  DataCell(
                                    SelectableText(
                                      key['license_key'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(key['activated_by'] ?? '-')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_statusIcon(status), size: 14, color: _statusColor(status)),
                                          const SizedBox(width: 4),
                                          Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(
                                    createdAt != null
                                        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                        : '-',
                                    style: const TextStyle(fontSize: 13),
                                  )),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          tooltip: 'Copy Key',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: key['license_key'] ?? ''));
                                            _showSnackBar('License key copied to clipboard');
                                          },
                                        ),
                                        if (status == 'active')
                                          IconButton(
                                            icon: const Icon(Icons.email_outlined, size: 18),
                                            tooltip: 'Resend Email',
                                            onPressed: () async {
                                              final email = key['activated_by'];
                                              if (email != null && email.toString().isNotEmpty) {
                                                // Re-generate sends a new key; for resend we just notify
                                                _showSnackBar('Use "Generate Key" to send a new key to $email');
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
