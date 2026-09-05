import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'ownership_calculators.dart';
import 'ai_chat_screen.dart';
import 'main_screen.dart';
import '../services/auth_service.dart';

class CarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> car;

  const CarDetailScreen({super.key, required this.car});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  bool _isFavourite = false;
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  bool _isLoadingFav = true;
  late Map<String, dynamic> _car;

  @override
  void initState() {
    super.initState();
    _car = Map<String, dynamic>.from(widget.car);
    _checkFavouriteStatus();
    _fetchLiveCarFromDatabase();
  }

  Future<void> _fetchLiveCarFromDatabase() async {
    final carId = _car['id'];
    final make = _car['make'];
    final model = _car['model'];
    try {
      Map<String, dynamic>? liveData;
      if (carId != null && carId.toString().isNotEmpty) {
        liveData = await _supabase
            .from('cars')
            .select()
            .eq('id', carId)
            .maybeSingle();
      }
      if (liveData == null && make != null && model != null) {
        liveData = await _supabase
            .from('cars')
            .select()
            .ilike('make', make.toString().trim())
            .ilike('model', model.toString().trim())
            .maybeSingle();
      }
      if (liveData != null && mounted) {
        setState(() {
          _car = {..._car, ...liveData!};
        });
      }
    } catch (e) {
      debugPrint('Error fetching live car details: $e');
    }
  }

  Future<void> _checkFavouriteStatus() async {
    final user = _authService.currentUser;
    final carId = _car['id'] ?? widget.car['id'];
    if (user == null || carId == null) {
      if (mounted) setState(() => _isLoadingFav = false);
      return;
    }

    try {
      final response = await _supabase
          .from('favourite_indicators')
          .select('id')
          .eq('user_id', user.id)
          .eq('car_id', widget.car['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavourite = response != null;
          _isLoadingFav = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking favourite: $e');
      if (mounted) setState(() => _isLoadingFav = false);
    }
  }

  Future<void> _toggleFavourite() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save cars'), backgroundColor: Colors.orange),
      );
      return;
    }

    final carId = _car['id'] ?? widget.car['id'];
    if (carId == null) return;

    final wasFavourite = _isFavourite;
    setState(() => _isFavourite = !_isFavourite);

    try {
      if (wasFavourite) {
        await _supabase
            .from('favourite_indicators')
            .delete()
            .eq('user_id', user.id)
            .eq('car_id', carId);
      } else {
        await _supabase.from('favourite_indicators').insert({
          'user_id': user.id,
          'car_id': carId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling favourite: $e');
      if (mounted) {
        setState(() => _isFavourite = wasFavourite);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favourite: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  double _calculateEstimatedRoadTax(bool isEV, num? engineCC, num? motorPower) {
    if (isEV) {
      final double kw = motorPower?.toDouble() ?? 100.0;
      if (kw <= 50.0) return 20.0;
      if (kw <= 60.0) return 30.0;
      if (kw <= 70.0) return 40.0;
      if (kw <= 80.0) return 50.0;
      if (kw <= 90.0) return 60.0;
      if (kw <= 100.0) return 70.0;
      if (kw <= 110.0) return 80.0;
      if (kw <= 120.0) return 90.0;
      if (kw <= 130.0) return 100.0;
      if (kw <= 140.0) return 110.0;
      if (kw <= 150.0) return 120.0;
      return 150.0;
    }
    final int cc = engineCC?.toInt() ?? 1500;
    if (cc <= 1000) return 20.0;
    if (cc <= 1200) return 55.0;
    if (cc <= 1400) return 70.0;
    if (cc <= 1600) return 90.0;
    if (cc <= 1800) return 200.0 + (cc - 1600) * 0.40;
    if (cc <= 2000) return 280.0 + (cc - 1800) * 0.50;
    if (cc <= 2500) return 380.0 + (cc - 2000) * 1.00;
    if (cc <= 3000) return 880.0 + (cc - 2500) * 2.50;
    return 2130.0 + (cc - 3000) * 4.50;
  }

  @override
  Widget build(BuildContext context) {
    final car = _car;
    final String? imageUrl = car['imageUrl'] ?? car['image_url'];
    final bool isEV = car['isEV'] == true ||
        car['is_ev'] == true ||
        (car['fuelType']?.toString().toLowerCase().contains('ev') ?? false) ||
        (car['fuel_type']?.toString().toLowerCase().contains('ev') ?? false);

    final double price = (car['price'] as num?)?.toDouble() ?? 0.0;
    final num? engineCC = car['engineCC'] ?? car['engine_cc'];
    final num? motorPower = car['motorPower'] ?? car['motor_power'] ?? car['power'];
    final double fuelConsumption = (car['fuelConsumption'] ?? car['fuel_consumption'] as num?)?.toDouble() ?? (isEV ? 15.0 : 6.0);
    final String fuelTypeStr = isEV ? 'Electric (EV)' : (car['fuelType'] ?? car['fuel_type']?.toString() ?? 'Petrol');
    final String? bodyType = car['bodyType'] ?? car['body_type'];
    final String? transmission = car['transmission']?.toString();
    final int? year = (car['year'] as num?)?.toInt();

    final double principal = price * 0.9;
    final double totalLoanPayable = principal * (1.0 + (0.032 * 9));
    final double monthlyLoan = price > 0 ? (totalLoanPayable / 108) : 0;
    final double roadTaxAnnual = _calculateEstimatedRoadTax(isEV, engineCC, motorPower);
    final double monthlyEnergy = isEV
        ? (10.0 * fuelConsumption * 0.57)
        : (10.0 * fuelConsumption * 2.05);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.secondary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoadingFav)
            IconButton(
              icon: Icon(
                _isFavourite ? Icons.favorite : Icons.favorite_border,
                color: _isFavourite ? AppColors.accentRed : Colors.white,
              ),
              onPressed: _toggleFavourite,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 260,
              width: double.infinity,
              color: const Color(0xFF0F172A),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Hero(
                          tag: 'car_img_${car['id'] ?? "${car['make']} ${car['model']}"}',
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.directions_car, color: Colors.white38, size: 80),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.directions_car, size: 90, color: Colors.white54),
                        ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEV ? Icons.bolt_rounded : Icons.local_gas_station_rounded,
                            size: 14,
                            color: isEV ? const Color(0xFF10B981) : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEV ? 'EV' : (year != null ? '$year' : 'ICE'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (isEV)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '⚡ Zero Emission EV',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (bodyType != null && bodyType.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      bodyType,
                                      style: const TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (year != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$year Model',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.secondary,
                          Color(0xFF2C3E50),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTIMATED OTR PRICE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'RM ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                              style: const TextStyle(
                                fontSize: 26,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Excl. Insurance',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Key Specifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          icon: isEV ? Icons.electric_bolt_rounded : Icons.speed_rounded,
                          iconColor: isEV ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                          title: isEV ? 'Motor Power' : 'Engine Capacity',
                          value: isEV
                              ? (motorPower != null && motorPower > 0
                                  ? '${motorPower.toInt()} kW'
                                  : 'Electric Drive')
                              : (engineCC != null && engineCC > 0 ? '$engineCC cc' : 'N/A'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          icon: isEV ? Icons.battery_charging_full_rounded : Icons.local_gas_station_rounded,
                          iconColor: isEV ? const Color(0xFF10B981) : AppColors.primary,
                          title: 'Energy Standard',
                          value: fuelTypeStr,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.eco_rounded,
                          iconColor: const Color(0xFF059669),
                          title: 'Consumption',
                          value: '${fuelConsumption.toStringAsFixed(1)} ${isEV ? "kWh/100km" : "L/100km"}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.settings_suggest_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Transmission',
                          value: transmission != null && transmission.isNotEmpty
                              ? transmission
                              : (isEV ? 'Single-speed Direct Drive' : 'Automatic'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.directions_car_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                          title: 'Body Type',
                          value: bodyType != null && bodyType.isNotEmpty
                              ? bodyType
                              : 'Standard',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.receipt_long_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Est. Road Tax',
                          value: 'RM ${roadTaxAnnual.round()} / year',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ownership Snapshot',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => OwnershipCalculators(car: car)),
                          );
                        },
                        child: const Text(
                          'Full TCO >',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => OwnershipCalculators(car: car)),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSnapshotCol(
                                  label: 'Est. Loan',
                                  value: monthlyLoan > 0 ? 'RM ${monthlyLoan.round()}' : 'N/A',
                                  sublabel: '/ month (9 yrs)',
                                  color: AppColors.primary,
                                ),
                              ),
                              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                              Expanded(
                                child: _buildSnapshotCol(
                                  label: 'Road Tax',
                                  value: 'RM ${roadTaxAnnual.round()}',
                                  sublabel: '/ year (JPJ)',
                                  color: AppColors.secondary,
                                ),
                              ),
                              Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                              Expanded(
                                child: _buildSnapshotCol(
                                  label: isEV ? 'Est. Charge' : 'Est. Fuel',
                                  value: 'RM ${monthlyEnergy.round()}',
                                  sublabel: '/ 1,000 km',
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app_outlined, size: 14, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Tap here to customize loan, road tax & fuel calculations',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OwnershipCalculators(car: car)),
                        );
                      },
                      icon: const Icon(Icons.calculate_rounded, color: Colors.white),
                      label: const Text(
                        'Calculate Cost of Ownership',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        final msg = "What can you tell me about the ${car['make']} ${car['model']}? Should I consider it?";
                        final mainScreen = MainScreen.globalKey.currentState;
                        if (mainScreen != null) {
                          mainScreen.navigateToAiChat(msg);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AiChatScreen(initialMessage: msg),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                      label: const Text(
                        'Ask AI About This Car',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCol({
    required String label,
    required String value,
    required String sublabel,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
