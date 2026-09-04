import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'dealership_map_screen.dart';
import 'ownership_calculators.dart';
import 'transit_comparator_screen.dart';
import 'car_browse_screen.dart';
import 'car_detail_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../services/dynamic_fetch_service.dart';
import '../models/car_model.dart';

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
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Snap & Identify', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
        content: const Text('Choose image source:', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
        ],
      ),
    );
    
    if (source == null) return;
    
    final XFile? image = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 80);
    if (image == null) return;
    
    final bytes = await image.readAsBytes();
    String mimeType = 'image/jpeg';
    if (image.name.toLowerCase().endsWith('.png')) mimeType = 'image/png';
    else if (image.name.toLowerCase().endsWith('.webp')) mimeType = 'image/webp';
    
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('AI is analyzing the car...', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ],
            ),
          ),
        ),
      ),
    );
    
    final aiService = DynamicFetchService();
    CarModel? car;
    bool isNotCar = false;
    bool isNoInternet = false;
    
    try {
      car = await aiService.fetchCarFromImage(bytes, mimeType);
    } catch (e) {
      if (e.toString().contains('not_a_car')) {
        isNotCar = true;
      } else if (e.toString().contains('no_internet')) {
        isNoInternet = true;
      }
    }
    
    if (!context.mounted) return;
    Navigator.pop(context);
    
    if (isNoInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please connect to the internet and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } else if (isNotCar) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('No Car Detected'),
            ],
          ),
          content: const Text('AI could not find a car in this image. Please upload a clear photo of a vehicle.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (car != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Identified as ${car.make} ${car.model}!'), backgroundColor: AppColors.accentGreen),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CarDetailScreen(car: car!.toJson())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI could not process the request. Please try again.'), backgroundColor: Colors.orange),
      );
    }
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
        final String dateDisplay = dateStr.isNotEmpty ? ' (Updated: $dateStr)' : '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Fuel Prices$dateDisplay',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFuelItem('RON95', data?['RON95 (Floating)'], Colors.amber.shade600),
                const SizedBox(width: 6),
                _buildFuelItem('R95 BUDI', data?['RON95 (BUDI 95)'], Colors.amber.shade500),
                const SizedBox(width: 6),
                _buildFuelItem('R95 SKPS', data?['RON95 (SKPS)'], Colors.orange),
                const SizedBox(width: 6),
                _buildFuelItem('RON97', data?['RON97'], Colors.green.shade600),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFuelItem('Dsl (Pen)', data?['Diesel (Peninsular)'], Colors.grey.shade800),
                const SizedBox(width: 6),
                _buildFuelItem('Dsl (E.M)', data?['Diesel (Sbh/Swk)'], Colors.grey.shade600),
                const SizedBox(width: 6),
                _buildFuelItem('Dsl BUDI', data?['Diesel (BUDI)'], Colors.blueGrey.shade800),
                const SizedBox(width: 6),
                _buildFuelItem('Dsl SKDS', data?['Diesel (SKDS)'], Colors.black87),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFuelItem(String type, dynamic price, Color color) {
    final String priceStr = price != null ? 'RM ${(price as num).toStringAsFixed(2)}' : '---';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                priceStr,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
