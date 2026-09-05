import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'dealership_map_screen.dart';
import 'ownership_calculators.dart';
import 'transit_comparator_screen.dart';
import 'car_browse_screen.dart';
import '../services/snap_identify_helper.dart';

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
                  _buildSnapIdentifyCard(context),
                  const SizedBox(height: 24),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  _buildCommuteCard(context),
                  const SizedBox(height: 24),
                  _buildDealershipCard(context),
                  const SizedBox(height: 32),
                  _buildFuelPriceCard(),
                  
                  const SizedBox(height: 100),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
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

  Widget _buildSnapIdentifyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF2575FC).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSnapIdentify(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Snap & Identify',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'See a car you like? Snap a photo to get its specs and price instantly!',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSnapIdentify(BuildContext context) async {
    await SnapIdentifyHelper.handleSnapIdentify(context);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _buildActionCard(
          context,
          'Browse Cars',
          'Explore specs & MY trends',
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
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
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Nearby Dealerships', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)])),
                  Text('Explore verified showrooms in MY', style: TextStyle(color: Colors.white, fontSize: 14, shadows: [Shadow(blurRadius: 4)])),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DealershipMapScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.location_on, size: 16),
                label: const Text('View Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            // Header: title + info icon + updated date
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
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
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
            // Table card
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
                  // Column headers
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
                  // Fuel rows
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
                              // Colored dot
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: f['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Fuel name
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
                              // Price
                              Expanded(
                                flex: 3,
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
}
