import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../models/car_model.dart';
import 'car_detail_screen.dart';
import 'login_screen.dart';

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

  Future<void> _loadFavourites({bool forceRefresh = false}) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _favouriteCars = [];
            _isLoading = false;
          });
        }
        return;
      }

      final favouriteCars = await _dataService.fetchFavouriteCars(forceRefresh: forceRefresh);

      if (mounted) {
        setState(() {
          _favouriteCars = favouriteCars;
          _isLoading = false;
        });
      }

      if (!forceRefresh) {
        _syncFavouritesInBackground();
      }
    } catch (e) {
      debugPrint('Error loading favourites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncFavouritesInBackground() async {
    try {
      final freshFavs = await _dataService.fetchFavouriteCars(forceRefresh: true);
      if (!mounted) return;
      if (freshFavs.length != _favouriteCars.length || !_areListsEqual(freshFavs, _favouriteCars)) {
        setState(() {
          _favouriteCars = freshFavs;
        });
      }
    } catch (_) {}
  }

  bool _areListsEqual(List<CarModel> a, List<CarModel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accentRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _authService.currentUser == null ? Icons.favorite_rounded : Icons.favorite_border,
                            size: 48,
                            color: AppColors.accentRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _authService.currentUser == null ? 'Sign in to view saved cars' : 'No saved cars yet',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _authService.currentUser == null
                              ? 'Your saved vehicles are safely synced to your account. Sign in to access your shortlist.'
                              : 'Tap the heart icon on any car to save it to your favourites list.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                        ),
                        if (_authService.currentUser == null) ...[
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ).then((_) => _loadFavourites());
                            },
                            child: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadFavourites(forceRefresh: true),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favouriteCars.length,
                    itemBuilder: (context, index) {
                      final car = _favouriteCars[index];
                      return _buildCarCard(car);
                    },
                  ),
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
                  if (user == null || car.id == null) return;
                  try {
                    await _supabase
                        .from('favourite_indicators')
                        .delete()
                        .eq('user_id', user.id)
                        .eq('car_id', car.id as Object);
                    final favIds = await _dataService.getFavouriteCarIds();
                    favIds.remove(car.id.toString());
                    await _dataService.saveCachedFavouriteIds(user.id, favIds);
                    _loadFavourites();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No internet connection. Cannot update saved cars while offline.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
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
