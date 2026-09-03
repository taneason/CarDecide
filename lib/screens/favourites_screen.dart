import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../models/car_model.dart';
import 'car_detail_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  final _dataService = DataService();
  
  bool _isLoading = true;
  List<CarModel> _favouriteCars = [];

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Fetch favourite car IDs
      final favResponse = await _supabase
          .from('favourite_indicators')
          .select('car_id')
          .eq('user_id', user.id);

      final List<dynamic> favList = favResponse as List<dynamic>;
      final favCarIds = favList.map((e) => e['car_id'].toString()).toSet();

      if (favCarIds.isEmpty) {
        if (mounted) {
          setState(() {
            _favouriteCars = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch all cars and filter
      final allCars = await _dataService.fetchCars();
      final favouriteCars = allCars.where((car) => favCarIds.contains(car.id)).toList();

      if (mounted) {
        setState(() {
          _favouriteCars = favouriteCars;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favourites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Cars', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _favouriteCars.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No saved cars yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _favouriteCars.length,
                  itemBuilder: (context, index) {
                    final car = _favouriteCars[index];
                    return _buildCarCard(car);
                  },
                ),
    );
  }

  Widget _buildCarCard(CarModel car) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => CarDetailScreen(car: car.toJson())),
          ).then((_) => _loadFavourites());
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 105,
                  height: 85,
                  color: AppColors.background,
                  child: car.imageUrl != null && car.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: car.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: SizedBox(
                                width: 20, 
                                height: 20, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.directions_car, color: Colors.grey),
                          ),
                        )
                      : const Center(child: Icon(Icons.directions_car, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.fullName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          "${car.fuelConsumption}L/100km",
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "RM ${car.price.toStringAsFixed(0)}",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: AppColors.accentRed),
                onPressed: () async {
                  final user = _authService.currentUser;
                  if (user == null) return;
                  try {
                    await _supabase
                        .from('favourite_indicators')
                        .delete()
                        .eq('user_id', user.id)
                        .eq('car_id', car.id as Object);
                    _loadFavourites();
                  } catch (e) {
                    debugPrint('Error removing fav: $e');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
