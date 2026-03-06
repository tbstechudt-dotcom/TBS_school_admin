import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/auth_provider.dart';
import '../../services/supabase_service.dart';

class FeeCollectionScreen extends StatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  State<FeeCollectionScreen> createState() => _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends State<FeeCollectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            indicator: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: const [
              Tab(text: 'Fee Collection'),
              Tab(text: 'Class-wise Demand'),
              Tab(text: 'Date-wise'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _FeeCollectionTab(),
              _ClassWiseDemandTab(),
              _DateWiseTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== Tab 1: Fee Collection (Date-wise Collection) ====================

class _FeeCollectionTab extends StatefulWidget {
  const _FeeCollectionTab();

  @override
  State<_FeeCollectionTab> createState() => _FeeCollectionTabState();
}

class _FeeCollectionTabState extends State<_FeeCollectionTab> with AutomaticKeepAliveClientMixin {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  List<Map<String, dynamic>> _payments = [];
  List<_DateGroup> _dateGroups = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final auth = context.read<AuthProvider>();
    final insId = auth.insId;
    if (insId == null) return;

    setState(() => _isLoading = true);

    final payments = await SupabaseService.getPaymentsByDateRange(
      insId,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in payments) {
      final dateStr = _extractDate(p['paydate']);
      grouped.putIfAbsent(dateStr, () => []).add(p);
    }

    final dateGroups = grouped.entries.map((e) {
      double total = 0;
      for (final p in e.value) {
        total += (p['transtotalamount'] as num?)?.toDouble() ?? 0;
      }
      return _DateGroup(date: e.key, payments: e.value, totalAmount: total);
    }).toList();

    dateGroups.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _payments = payments;
        _dateGroups = dateGroups;
        _isLoading = false;
      });
    }
  }

  String _extractDate(dynamic paydate) {
    if (paydate == null) return 'Unknown';
    try {
      final dt = DateTime.parse(paydate.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return paydate.toString().split('T').first;
    }
  }

  String _formatDisplayDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(pattern, (m) => '${m[1]},');
    return '₹$formatted';
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchData();
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      final dt = DateTime.parse(timestamp.toString());
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '-';
    }
  }

  String _formatFilterDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  double get _totalCollection => _payments.fold(0.0, (sum, p) => sum + ((p['transtotalamount'] as num?)?.toDouble() ?? 0));
  int get _totalTransactions => _payments.length;
  int get _collectionDays => _dateGroups.length;
  double get _avgPerDay => _collectionDays > 0 ? _totalCollection / _collectionDays : 0;

  Widget _buildDateChip(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(_formatFilterDate(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, Color iconColor, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateGroupTile(_DateGroup group, int index) {
    final auth = context.read<AuthProvider>();
    return _DateGroupTile(
      group: group,
      index: index,
      insId: auth.insId,
      formatCurrency: _formatCurrency,
      formatDisplayDate: _formatDisplayDate,
      formatTime: _formatTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date filter bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Date Range:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  _buildDateChip('From', _fromDate, () => _pickDate(true)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  _buildDateChip('To', _toDate, () => _pickDate(false)),
                  const SizedBox(width: 12),
                  _buildQuickFilter('Today', () {
                    setState(() {
                      _fromDate = DateTime.now();
                      _toDate = DateTime.now();
                    });
                    _fetchData();
                  }),
                  const SizedBox(width: 6),
                  _buildQuickFilter('7 Days', () {
                    setState(() {
                      _toDate = DateTime.now();
                      _fromDate = DateTime.now().subtract(const Duration(days: 7));
                    });
                    _fetchData();
                  }),
                  const SizedBox(width: 6),
                  _buildQuickFilter('30 Days', () {
                    setState(() {
                      _toDate = DateTime.now();
                      _fromDate = DateTime.now().subtract(const Duration(days: 30));
                    });
                    _fetchData();
                  }),
                  const SizedBox(width: 6),
                  _buildQuickFilter('This Month', () {
                    final now = DateTime.now();
                    setState(() {
                      _fromDate = DateTime(now.year, now.month, 1);
                      _toDate = now;
                    });
                    _fetchData();
                  }),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                    onPressed: _fetchData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Summary cards
            Row(
              children: [
                _buildSummaryCard(Icons.currency_rupee, AppColors.accent, _formatCurrency(_totalCollection), 'Total Collection'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.receipt_long, Colors.blue, _totalTransactions.toString(), 'Total Transactions'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.calendar_month, Colors.orange, _collectionDays.toString(), 'Collection Days'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.trending_up, AppColors.warning, _formatCurrency(_avgPerDay), 'Avg / Day'),
              ],
            ),
            const SizedBox(height: 16),
            // Date-wise collection list
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        const Text('Date-wise Collection Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${_dateGroups.length} days', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_dateGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text('No collections found for selected date range', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_dateGroups.length, (i) => _buildDateGroupTile(_dateGroups[i], i + 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Tab 2: Class-wise Demand ====================

class _ClassWiseDemandTab extends StatefulWidget {
  const _ClassWiseDemandTab();

  @override
  State<_ClassWiseDemandTab> createState() => _ClassWiseDemandTabState();
}

class _ClassWiseDemandTabState extends State<_ClassWiseDemandTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<_ClassGroup> _classGroups = [];
  String? _selectedClass;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(pattern, (m) => '${m[1]},');
    return '₹$formatted';
  }

  int _compareClass(String a, String b) {
    const order = ['PKG', 'LKG', 'UKG', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
    final ia = order.indexOf(a);
    final ib = order.indexOf(b);
    if (ia != -1 && ib != -1) return ia.compareTo(ib);
    if (ia != -1) return -1;
    if (ib != -1) return 1;
    return a.compareTo(b);
  }

  Future<void> _fetchData() async {
    final auth = context.read<AuthProvider>();
    final insId = auth.insId;
    if (insId == null) return;

    setState(() => _isLoading = true);

    final demands = await SupabaseService.getFeeDemands(insId);

    // Fetch student names by stu_id (since student join may fail)
    final stuIds = demands.map((d) => d['stu_id']).where((id) => id != null).toSet().toList();
    final Map<int, String> stuIdToName = {};
    if (stuIds.isNotEmpty) {
      try {
        final client = SupabaseService.client;
        final students = await client.from('students')
            .select('stu_id, stuname')
            .inFilter('stu_id', stuIds);
        for (final s in (students as List)) {
          stuIdToName[s['stu_id'] as int] = s['stuname']?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('Error fetching student names: $e');
      }
    }
    // Attach student name to each demand
    for (final d in demands) {
      final stuId = d['stu_id'] as int?;
      if (stuId != null && stuIdToName.containsKey(stuId)) {
        d['_stuname'] = stuIdToName[stuId];
      }
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final d in demands) {
      final cls = d['stuclass']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(cls, () => []).add(d);
    }

    final classGroups = grouped.entries.map((e) {
      double totalDemand = 0;
      double totalPaid = 0;
      double totalPending = 0;
      double totalConcession = 0;
      final Set<String> studentAdmNos = {};
      final Set<String> feeTypeSet = {};

      for (final d in e.value) {
        final fee = (d['feeamount'] as num?)?.toDouble() ?? 0;
        final con = (d['conamount'] as num?)?.toDouble() ?? 0;
        final paid = (d['paidamount'] as num?)?.toDouble() ?? 0;
        final balance = (d['balancedue'] as num?)?.toDouble() ?? 0;
        totalDemand += fee;
        totalConcession += con;
        totalPaid += paid;
        totalPending += balance;
        final admNo = d['stuadmno']?.toString() ?? '';
        if (admNo.isNotEmpty) studentAdmNos.add(admNo);
        final feeType = d['demfeetype']?.toString() ?? '';
        if (feeType.isNotEmpty) feeTypeSet.add(feeType);
      }

      final feeTypes = feeTypeSet.toList()..sort();

      return _ClassGroup(
        className: e.key,
        demands: e.value,
        totalDemand: totalDemand,
        totalConcession: totalConcession,
        totalPaid: totalPaid,
        totalPending: totalPending,
        studentCount: studentAdmNos.length,
        feeTypes: feeTypes,
      );
    }).toList();

    classGroups.sort((a, b) => _compareClass(a.className, b.className));

    if (mounted) {
      setState(() {
        _classGroups = classGroups;
        _isLoading = false;
      });
    }
  }

  // Summary totals
  double get _totalDemand => _classGroups.fold(0.0, (s, g) => s + g.totalDemand);
  double get _totalPaid => _classGroups.fold(0.0, (s, g) => s + g.totalPaid);
  double get _totalPending => _classGroups.fold(0.0, (s, g) => s + g.totalPending);
  int get _totalStudents => _classGroups.fold(0, (s, g) => s + g.studentCount);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // If a class is selected, show student drilldown
    if (_selectedClass != null) {
      final group = _classGroups.firstWhere((g) => g.className == _selectedClass, orElse: () => _classGroups.first);
      return _buildStudentDrilldown(group);
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Summary cards
            Row(
              children: [
                _buildSummaryCard(Icons.account_balance_wallet, AppColors.accent, _formatCurrency(_totalDemand), 'Total Demand'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.check_circle_outline, AppColors.success, _formatCurrency(_totalPaid), 'Total Collected'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.pending_outlined, AppColors.warning, _formatCurrency(_totalPending), 'Total Pending'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.people_alt_outlined, Colors.blue, _totalStudents.toString(), 'Total Students'),
              ],
            ),
            const SizedBox(height: 16),
            // Class-wise table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        const Text('Class-wise Fee Demand', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${_classGroups.length} classes', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: AppColors.surface,
                    child: const Row(
                      children: [
                        SizedBox(width: 36),
                        Expanded(flex: 2, child: Text('Class', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('Students', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 3, child: Text('Fee Types', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Total Demand', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Pending', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('% Collected', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        SizedBox(width: 32),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_classGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text('No fee demands found', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_classGroups.length, (i) {
                      final g = _classGroups[i];
                      final pct = g.totalDemand > 0 ? (g.totalPaid / g.totalDemand * 100) : 0.0;
                      return InkWell(
                        onTap: () => setState(() => _selectedClass = g.className),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Text(g.className, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              Expanded(flex: 1, child: Text('${g.studentCount}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 3, child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: g.feeTypes.map((ft) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(ft, style: const TextStyle(fontSize: 9, color: AppColors.accent)),
                                )).toList(),
                              )),
                              Expanded(flex: 2, child: Text(_formatCurrency(g.totalDemand), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                              Expanded(flex: 2, child: Text(_formatCurrency(g.totalPaid), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.success))),
                              Expanded(flex: 2, child: Text(_formatCurrency(g.totalPending), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: g.totalPending > 0 ? AppColors.warning : AppColors.textSecondary))),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: pct >= 100
                                          ? AppColors.success.withValues(alpha: 0.1)
                                          : pct >= 50
                                              ? Colors.orange.withValues(alpha: 0.1)
                                              : AppColors.warning.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${pct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: pct >= 100 ? AppColors.success : pct >= 50 ? Colors.orange : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32, child: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDrilldown(_ClassGroup group) {
    // Group demands by student (stuadmno)
    final Map<String, List<Map<String, dynamic>>> byStudent = {};
    for (final d in group.demands) {
      final admNo = d['stuadmno']?.toString() ?? 'Unknown';
      byStudent.putIfAbsent(admNo, () => []).add(d);
    }

    return Column(
      children: [
        // Back button header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _selectedClass = null),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text('Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.school_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Class ${group.className} — Student Fee Details', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${byStudent.length} students', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Student accordion list
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: AppColors.surface,
                    child: const Row(
                      children: [
                        SizedBox(width: 36),
                        Expanded(flex: 1, child: Text('Adm No', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 3, child: Text('Student Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Fee Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        SizedBox(width: 60, child: Center(child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
                        SizedBox(width: 32),
                      ],
                    ),
                  ),
                  ...List.generate(byStudent.length, (i) {
                    final admNo = byStudent.keys.elementAt(i);
                    final studentDemands = byStudent[admNo]!;
                    return _StudentAccordion(
                      index: i + 1,
                      admNo: admNo,
                      demands: studentDemands,
                      formatCurrency: _formatCurrency,
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(IconData icon, Color iconColor, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Tab 3: Date-wise (Fee Demand by Date) ====================

class _DateWiseTab extends StatefulWidget {
  const _DateWiseTab();

  @override
  State<_DateWiseTab> createState() => _DateWiseTabState();
}

class _DateWiseTabState extends State<_DateWiseTab> with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  List<_DateDemandGroup> _dateGroups = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final pattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(pattern, (m) => '${m[1]},');
    return '₹$formatted';
  }

  String _formatDisplayDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _fetchData() async {
    final auth = context.read<AuthProvider>();
    final insId = auth.insId;
    if (insId == null) return;

    setState(() => _isLoading = true);

    final demands = await SupabaseService.getFeeDemands(insId);

    // Group by createdat date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final d in demands) {
      final dateStr = _extractDate(d['createdat']);
      grouped.putIfAbsent(dateStr, () => []).add(d);
    }

    final dateGroups = grouped.entries.map((e) {
      double totalDemand = 0, totalPaid = 0, totalPending = 0;
      final Set<String> students = {};
      for (final d in e.value) {
        totalDemand += (d['feeamount'] as num?)?.toDouble() ?? 0;
        totalPaid += (d['paidamount'] as num?)?.toDouble() ?? 0;
        totalPending += (d['balancedue'] as num?)?.toDouble() ?? 0;
        final admNo = d['stuadmno']?.toString() ?? '';
        if (admNo.isNotEmpty) students.add(admNo);
      }
      return _DateDemandGroup(
        date: e.key,
        demands: e.value,
        totalDemand: totalDemand,
        totalPaid: totalPaid,
        totalPending: totalPending,
        studentCount: students.length,
      );
    }).toList();

    dateGroups.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _dateGroups = dateGroups;
        _isLoading = false;
      });
    }
  }

  String _extractDate(dynamic dt) {
    if (dt == null) return 'Unknown';
    try {
      final parsed = DateTime.parse(dt.toString());
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt.toString().split('T').first;
    }
  }

  double get _totalDemand => _dateGroups.fold(0.0, (s, g) => s + g.totalDemand);
  double get _totalPaid => _dateGroups.fold(0.0, (s, g) => s + g.totalPaid);
  double get _totalPending => _dateGroups.fold(0.0, (s, g) => s + g.totalPending);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Summary cards
            Row(
              children: [
                _buildSummaryCard(Icons.account_balance_wallet, AppColors.accent, _formatCurrency(_totalDemand), 'Total Demand'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.check_circle_outline, AppColors.success, _formatCurrency(_totalPaid), 'Total Paid'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.pending_outlined, AppColors.warning, _formatCurrency(_totalPending), 'Total Pending'),
                const SizedBox(width: 16),
                _buildSummaryCard(Icons.calendar_month, Colors.blue, '${_dateGroups.length}', 'Demand Dates'),
              ],
            ),
            const SizedBox(height: 16),
            // Date-wise demand table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        const Text('Date-wise Fee Demand', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${_dateGroups.length} dates', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    color: AppColors.surface,
                    child: const Row(
                      children: [
                        SizedBox(width: 36),
                        Expanded(flex: 3, child: Text('Date', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('Students', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Demand', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 2, child: Text('Pending', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                        Expanded(flex: 1, child: Text('% Collected', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_dateGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text('No fee demands found', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...List.generate(_dateGroups.length, (i) {
                      final g = _dateGroups[i];
                      final pct = g.totalDemand > 0 ? (g.totalPaid / g.totalDemand * 100) : 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 3, child: Text(_formatDisplayDate(g.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                            Expanded(flex: 1, child: Text('${g.studentCount}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 2, child: Text(_formatCurrency(g.totalDemand), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                            Expanded(flex: 2, child: Text(_formatCurrency(g.totalPaid), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.success))),
                            Expanded(flex: 2, child: Text(_formatCurrency(g.totalPending), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: g.totalPending > 0 ? AppColors.warning : AppColors.textSecondary))),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: pct >= 100
                                        ? AppColors.success.withValues(alpha: 0.1)
                                        : pct >= 50
                                            ? Colors.orange.withValues(alpha: 0.1)
                                            : AppColors.warning.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${pct.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: pct >= 100 ? AppColors.success : pct >= 50 ? Colors.orange : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, Color iconColor, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Data Models ====================

class _DateGroup {
  final String date;
  final List<Map<String, dynamic>> payments;
  final double totalAmount;

  _DateGroup({
    required this.date,
    required this.payments,
    required this.totalAmount,
  });
}

class _ClassGroup {
  final String className;
  final List<Map<String, dynamic>> demands;
  final double totalDemand;
  final double totalConcession;
  final double totalPaid;
  final double totalPending;
  final int studentCount;
  final List<String> feeTypes; // "FeeGroup > FeeType" list

  _ClassGroup({
    required this.className,
    required this.demands,
    required this.totalDemand,
    required this.totalConcession,
    required this.totalPaid,
    required this.totalPending,
    required this.studentCount,
    this.feeTypes = const [],
  });
}

class _DateDemandGroup {
  final String date;
  final List<Map<String, dynamic>> demands;
  final double totalDemand;
  final double totalPaid;
  final double totalPending;
  final int studentCount;

  _DateDemandGroup({
    required this.date,
    required this.demands,
    required this.totalDemand,
    required this.totalPaid,
    required this.totalPending,
    required this.studentCount,
  });
}

// ==================== Date Group Tile ====================

class _DateGroupTile extends StatefulWidget {
  final _DateGroup group;
  final int index;
  final int? insId;
  final String Function(double) formatCurrency;
  final String Function(String) formatDisplayDate;
  final String Function(dynamic) formatTime;

  const _DateGroupTile({
    required this.group,
    required this.index,
    this.insId,
    required this.formatCurrency,
    required this.formatDisplayDate,
    required this.formatTime,
  });

  @override
  State<_DateGroupTile> createState() => _DateGroupTileState();
}

class _DateGroupTileState extends State<_DateGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _expanded ? AppColors.accent.withValues(alpha: 0.03) : Colors.transparent,
              border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${widget.index}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.formatDisplayDate(group.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${group.payments.length} transactions', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.formatCurrency(group.totalAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
                ),
                const SizedBox(width: 8),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.accent, size: 20),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            color: AppColors.surface,
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text('Pay ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Time', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Adm No', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Student Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Class', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Method', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                SizedBox(width: 32),
              ],
            ),
          ),
          ...group.payments.map((p) => _PaymentRow(
                payment: p,
                insId: widget.insId,
                formatCurrency: widget.formatCurrency,
                formatTime: widget.formatTime,
              )),
        ],
      ],
    );
  }
}

// ==================== Student Accordion ====================

class _StudentAccordion extends StatefulWidget {
  final int index;
  final String admNo;
  final List<Map<String, dynamic>> demands;
  final String Function(double) formatCurrency;

  const _StudentAccordion({
    required this.index,
    required this.admNo,
    required this.demands,
    required this.formatCurrency,
  });

  @override
  State<_StudentAccordion> createState() => _StudentAccordionState();
}

class _StudentAccordionState extends State<_StudentAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final demands = widget.demands;
    final stuName = demands.first['_stuname']?.toString() ?? '-';
    final totalFee = demands.fold<double>(0, (s, d) => s + ((d['feeamount'] as num?)?.toDouble() ?? 0));
    final totalPaid = demands.fold<double>(0, (s, d) => s + ((d['paidamount'] as num?)?.toDouble() ?? 0));
    final totalBalance = demands.fold<double>(0, (s, d) => s + ((d['balancedue'] as num?)?.toDouble() ?? 0));
    final allPaid = demands.every((d) => d['paidstatus'] == 'P');
    final anyPaid = demands.any((d) => d['paidstatus'] == 'P');

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _expanded ? AppColors.accent.withValues(alpha: 0.02) : Colors.transparent,
              border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('${widget.index}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                Expanded(flex: 1, child: Text(widget.admNo, style: const TextStyle(fontSize: 11))),
                Expanded(flex: 3, child: Text(stuName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                Expanded(flex: 2, child: Text(widget.formatCurrency(totalFee), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text(widget.formatCurrency(totalPaid), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.success))),
                Expanded(flex: 2, child: Text(widget.formatCurrency(totalBalance), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: totalBalance > 0 ? AppColors.warning : AppColors.textSecondary))),
                SizedBox(
                  width: 60,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: allPaid
                            ? AppColors.success.withValues(alpha: 0.1)
                            : anyPaid
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        allPaid ? 'Paid' : anyPaid ? 'Partial' : 'Unpaid',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: allPaid ? AppColors.success : anyPaid ? AppColors.warning : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.accent, size: 18),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                // Detail header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Term', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(flex: 3, child: Text('Fee Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                      SizedBox(width: 50, child: Center(child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
                    ],
                  ),
                ),
                // Detail rows
                ...demands.map((d) {
                  final isPaid = d['paidstatus'] == 'P';
                  final balance = (d['balancedue'] as num?)?.toDouble() ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(d['demfeeterm']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        Expanded(flex: 3, child: Text(d['demfeetype']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 2, child: Text(widget.formatCurrency((d['feeamount'] as num?)?.toDouble() ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                        Expanded(flex: 2, child: Text(widget.formatCurrency((d['paidamount'] as num?)?.toDouble() ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.success))),
                        Expanded(flex: 2, child: Text(widget.formatCurrency(balance), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: balance > 0 ? AppColors.warning : AppColors.textSecondary))),
                        SizedBox(
                          width: 50,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPaid ? 'Paid' : 'Due',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : AppColors.warning),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
    );
  }
}

// ==================== Payment Row ====================

class _PaymentRow extends StatefulWidget {
  final Map<String, dynamic> payment;
  final int? insId;
  final String Function(double) formatCurrency;
  final String Function(dynamic) formatTime;

  const _PaymentRow({
    required this.payment,
    this.insId,
    required this.formatCurrency,
    required this.formatTime,
  });

  @override
  State<_PaymentRow> createState() => _PaymentRowState();
}

class _PaymentRowState extends State<_PaymentRow> {
  bool _expanded = false;
  bool _loadingDetails = false;
  List<Map<String, dynamic>>? _feeDetails;

  Future<void> _toggleExpand() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    setState(() {
      _expanded = true;
      _loadingDetails = true;
    });

    if (_feeDetails == null) {
      final payId = widget.payment['pay_id'];
      if (payId != null) {
        final details = await SupabaseService.getFeeDetailsByPayId(payId as int, insId: widget.insId);
        if (mounted) {
          setState(() {
            _feeDetails = details;
            _loadingDetails = false;
          });
        }
      } else {
        setState(() => _loadingDetails = false);
      }
    } else {
      setState(() => _loadingDetails = false);
    }
  }

  List<Widget> _buildGroupedFeeDetails() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final fd in _feeDetails!) {
      final term = fd['demfeeterm']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(term, () => []).add(fd);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.06),
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ],
        ),
      ));
      for (final fd in entry.value) {
        final isPaid = fd['paidstatus'] == 'P';
        final balance = (fd['balancedue'] as num?)?.toDouble() ?? 0;
        final feeType = fd['demfeetype'] ?? '-';
        widgets.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  feeType,
                  style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                ),
              )),
              Expanded(flex: 2, child: Text(widget.formatCurrency((fd['feeamount'] as num?)?.toDouble() ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary))),
              Expanded(flex: 2, child: Text(widget.formatCurrency((fd['paidamount'] as num?)?.toDouble() ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.success))),
              Expanded(flex: 2, child: Text(widget.formatCurrency(balance), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: balance > 0 ? AppColors.warning : AppColors.textSecondary))),
              SizedBox(
                width: 50,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Due',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isPaid ? AppColors.success : AppColors.warning),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final student = p['students'] as Map<String, dynamic>?;
    final timeStr = widget.formatTime(p['createdat'] ?? p['paydate']);

    return Column(
      children: [
        InkWell(
          onTap: _toggleExpand,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _expanded ? AppColors.accent.withValues(alpha: 0.02) : Colors.transparent,
              border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(flex: 1, child: Text('#${p['pay_id'] ?? '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                Expanded(flex: 1, child: Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text(student?['stuadmno']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                Expanded(flex: 2, child: Text(student?['stuname']?.toString() ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                Expanded(flex: 1, child: Text(student?['stuclass']?.toString() ?? '-', style: const TextStyle(fontSize: 11))),
                Expanded(flex: 1, child: Text(p['paymethod'] ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                Expanded(flex: 1, child: Text(widget.formatCurrency((p['transtotalamount'] as num?)?.toDouble() ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success))),
                SizedBox(
                  width: 32,
                  child: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.accent, size: 18),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: _loadingDetails
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : (_feeDetails == null || _feeDetails!.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: Text('No fee details found for this payment', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Padding(
                                  padding: EdgeInsets.only(left: 18),
                                  child: Text('Fee Type', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                )),
                                Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Paid', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                                Expanded(flex: 2, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                                SizedBox(width: 50, child: Center(child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)))),
                              ],
                            ),
                          ),
                          ..._buildGroupedFeeDetails(),
                        ],
                      ),
          ),
      ],
    );
  }
}
