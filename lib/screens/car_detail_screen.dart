import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import 'ownership_calculators.dart';
import 'ai_chat_screen.dart';
import 'main_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _checkFavouriteStatus();
  }

  Future<void> _checkFavouriteStatus() async {
    final user = _authService.currentUser;
    if (user == null || widget.car['id'] == null) {
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
    
    final carId = widget.car['id'];
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

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final String? imageUrl = car['imageUrl'] ?? car['image_url'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${car['make']} ${car['model']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 240,
              width: double.infinity,
              color: Colors.grey.shade900,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Hero(
                      tag: 'car_img_${car['id'] ?? car['make'] + ' ' + car['model']}',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.directions_car, color: Colors.grey, size: 80),
                      ),
                    )
                  : const Center(child: Icon(Icons.directions_car, size: 90, color: Colors.white54)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${car['make']} ${car['model']}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (car['isEV'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.accentGreen, borderRadius: BorderRadius.circular(8)),
                          child: const Text('EV', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM ${car['price'].toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                    style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text('Key Specifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildSpecRow('Fuel Type', car['fuelType']?.toString() ?? 'Petrol'),
                  _buildSpecRow('Engine CC', (car['engineCC'] != null && (car['engineCC'] as num) > 0) ? '${car['engineCC']} cc' : 'N/A (Electric)'),
                  _buildSpecRow('Fuel Economy', '${car['fuelConsumption'] ?? 6.0} ${car['isEV'] == true ? "kWh/100km" : "L/100km"}'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OwnershipCalculators(initialPrice: car['price'].toDouble())),
                        );
                      },
                      child: const Text('Calculate Cost of Ownership', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Colors.black26,
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

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
