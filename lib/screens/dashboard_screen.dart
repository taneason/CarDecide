import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'dealership_map_screen.dart';
import 'ownership_calculators.dart';
import 'transit_comparator_screen.dart';
import 'car_browse_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final _dataService = DataService();
  Map<String, dynamic>? _profileData;
  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  void refresh() {
    _fetchProfile();
  }

  
  Future<void> _fetchProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profileData = data;
        });
      }
    } catch (e) {
      debugPrint('Fetch profile error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildCommuteCard(context),
                  const SizedBox(height: 24),
                  _buildDealershipCard(context),
                  const SizedBox(height: 32),
                  _buildFuelPriceCard(),
                  
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Widget _buildHeader() {
    final user = _authService.currentUser;
    final userName = user == null ? 'Guest' : (_profileData?['full_name'] ?? 'User');
    final avatarUrl = _profileData?['avatar_url'];
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.secondary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good morning', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(userName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Ready to decide?', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _buildActionCard(
          context,
          'Browse Cars',
          'Explore specs & prices',
          Icons.directions_car_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CarBrowseScreen())),
        ),
        const SizedBox(width: 16),
        _buildActionCard(
          context,
          'Cost Calculator',
          'Loan, road tax, petrol',
          Icons.calculate_outlined,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnershipCalculators())),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommuteCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TransitComparatorScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.near_me_outlined, color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Text('DRIVE VS. PUBLIC TRANSPORT', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                Spacer(),
                Icon(Icons.arrow_forward, color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Is a car worth it for your commute?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Compare real costs for your route', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDealershipCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DealershipMapScreen()));
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(24),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1526778548025-fa2f459cd5c1?auto=format&fit=crop&q=80&w=500'),
            fit: BoxFit.cover,
            opacity: 0.6,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Nearby Dealerships', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)])),
                        SizedBox(height: 2),
                        Text('Explore verified showrooms in MY', style: TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(blurRadius: 4)]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DealershipMapScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.location_on, size: 16),
                    label: const Text('View Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelPriceCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataService.fetchLatestFuelPrices(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final String dateStr = data?['_date'] ?? '';

        final fuels = [
          {'label': 'RON95',          'key': 'RON95 (Floating)',    'color': Colors.amber.shade600},
          {'label': 'RON95 BUDI',     'key': 'RON95 (BUDI 95)',    'color': Colors.amber.shade400},
          {'label': 'RON95 SKPS',     'key': 'RON95 (SKPS)',       'color': Colors.orange.shade600},
          {'label': 'RON97',          'key': 'RON97',              'color': Colors.green.shade600},
          {'label': 'Diesel (Pen.)',  'key': 'Diesel (Peninsular)','color': Colors.grey.shade700},
          {'label': 'Diesel (E.M.)', 'key': 'Diesel (Sbh/Swk)',   'color': Colors.blueGrey.shade400},
          {'label': 'Diesel BUDI',    'key': 'Diesel (BUDI)',      'color': Colors.blueGrey.shade800},
          {'label': 'Diesel SKDS',    'key': 'Diesel (SKDS)',      'color': const Color(0xFF37474F)},
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Text(
                      'Live Fuel Prices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showFuelPriceInfo(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.transparent,
                        child: const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    'Updated $dateStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Fuel Type',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Price (RM)',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ...fuels.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    final rawPrice = data?[f['key']];
                    final priceStr = rawPrice != null
                        ? (rawPrice as num).toStringAsFixed(2)
                        : null;
                    final isLast = i == fuels.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: f['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  f['label'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    priceStr != null ? 'RM $priceStr' : '—',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: priceStr != null
                                          ? AppColors.secondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(height: 1, indent: 36, endIndent: 16),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFuelPriceInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: const [
                    Icon(Icons.info_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Fuel Price Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Official Source: data.gov.my (Ministry of Finance)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFuelInfoItem(
                          'RON95 & Subsidies',
                          '• Floating: Official unsubsidised retail market rate.\n• BUDI 95: Targeted fuel subsidy rate for eligible citizens under BUDI MADANI.\n• SKPS: Subsidised petrol fleet quotas for public transport & taxis.',
                        ),
                        const SizedBox(height: 12),
                        _buildFuelInfoItem(
                          'RON97',
                          'Unsubsidised premium fuel priced according to weekly Automatic Pricing Mechanism (APM) and global MOPS benchmarks.',
                        ),
                        const SizedBox(height: 12),
                        _buildFuelInfoItem(
                          'Diesel & Targeted Retargeting',
                          '• Peninsular: Market price following nationwide diesel retargeting.\n• E.M. (Sabah & Sarawak): Subsidised retail rate maintained for East Malaysia.\n• BUDI & SKDS: Targeted cash aid / fleet cards for smallholders and logistics transport companies.',
                        ),
                        const SizedBox(height: 12),
                        _buildFuelInfoItem(
                          'Weekly Update Schedule',
                          'Fuel prices are updated every Wednesday/Thursday in accordance with the Malaysian Ministry of Finance weekly announcement.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Got it',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuelInfoItem(String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
