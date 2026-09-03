import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import '../models/car_model.dart';
import '../services/data_service.dart';
import '../services/dynamic_fetch_service.dart';
import 'car_detail_screen.dart';
import 'car_comparison_screen.dart';
import 'main_screen.dart';

class CarBrowseScreen extends StatefulWidget {
  final bool isSelectionMode;
  const CarBrowseScreen({super.key, this.isSelectionMode = false});

  @override
  State<CarBrowseScreen> createState() => _CarBrowseScreenState();
}

class _CarBrowseScreenState extends State<CarBrowseScreen> {
  final List<CarModel> _comparisonList = [];
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();
  List<CarModel> _allCars = [];
  List<CarModel> _filteredCars = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncProgressText = '';
  String _selectedFilter = 'All';
  
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  Set<String> _favouriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // Fetch cars
    final cars = await _dataService.fetchCars(forceRefresh: forceRefresh);
    
    // Fetch favourites
    Set<String> favs = {};
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final favResponse = await _supabase
            .from('favourite_indicators')
            .select('car_id')
            .eq('user_id', user.id);
        
        final List<dynamic> favList = favResponse as List<dynamic>;
        favs = favList.map((e) => e['car_id'].toString()).toSet();
      }
    } catch (e) {
      debugPrint('Error fetching favourites: $e');
    }
    
    if (mounted) {
      setState(() {
        _allCars = cars;
        _favouriteIds = favs;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  Future<void> _performDeepSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSyncing = true;
      _syncProgressText = 'AI is fetching specs for "$query"...';
    });

    try {
      final aiService = DynamicFetchService();
      CarModel? newCar;
      bool isNotCar = false;
      bool isNoInternet = false;
      
      try {
        newCar = await aiService.fetchCarFromAI(query);
      } catch (e) {
        if (e.toString().contains('not_a_car')) {
          isNotCar = true;
        } else if (e.toString().contains('no_internet')) {
          isNoInternet = true;
        } else {
          rethrow;
        }
      }
      
      if (!mounted) return;
      
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
                Text('Invalid Search'),
              ],
            ),
            content: Text('AI could not identify a valid car model from "$query". Please enter a valid car make and model.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (newCar != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully found ${newCar.fullName}!'), backgroundColor: AppColors.accentGreen),
        );
        // Reload data from DB so the new car shows up
        await _loadData(forceRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not find exact specs for this car.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deep Search Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _startOnlineSyncAndImageScrape() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncProgressText = 'Starting online image scrape...';
    });

    try {
      final updatedCars = await _dataService.forceSyncAndEnrichImages(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _syncProgressText = 'Auto-scraping photos: $current / $total';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _allCars = updatedCars;
          _applyFilters();
          _isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${updatedCars.length} cars with photos & saved to local storage!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleFavourite(CarModel car) async {
    final user = _authService.currentUser;
    if (user == null || car.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to save cars'), backgroundColor: Colors.orange),
      );
      return;
    }

    final isFav = _favouriteIds.contains(car.id);
    
    // Optimistic UI update
    setState(() {
      if (isFav) {
        _favouriteIds.remove(car.id);
      } else {
        _favouriteIds.add(car.id!);
      }
      _applyFilters();
    });

    try {
      if (isFav) {
        await _supabase.from('favourite_indicators').delete()
          .eq('user_id', user.id).eq('car_id', car.id as Object);
      } else {
        await _supabase.from('favourite_indicators').insert({
          'user_id': user.id,
          'car_id': car.id,
        });
      }
    } catch (e) {
      debugPrint('Error toggling favourite: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          if (isFav) {
            _favouriteIds.add(car.id!);
          } else {
            _favouriteIds.remove(car.id);
          }
          _applyFilters();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    List<CarModel> results = _allCars.where((car) {
      final nameMatch = car.fullName.toLowerCase().contains(query);

      bool priceMatch = true;
      if (_selectedFilter == 'Under 60k') {
        priceMatch = car.price < 60000;
      } else if (_selectedFilter == '60k-100k') {
        priceMatch = car.price >= 60000 && car.price <= 100000;
      } else if (_selectedFilter == 'Above 100k') {
        priceMatch = car.price > 100000;
      }

      return nameMatch && priceMatch;
    }).toList();

    // Sort so favourites are at the top
    results.sort((a, b) {
      final aFav = _favouriteIds.contains(a.id) ? 1 : 0;
      final bFav = _favouriteIds.contains(b.id) ? 1 : 0;
      if (aFav != bFav) {
        return bFav.compareTo(aFav);
      }
      return a.fullName.compareTo(b.fullName);
    });

    setState(() {
      _filteredCars = results;
    });
  }

  void _toggleComparison(CarModel car) {
    setState(() {
      if (_comparisonList.contains(car)) {
        _comparisonList.remove(car);
      } else {
        if (_comparisonList.length < 2) {
          _comparisonList.add(car);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can compare up to 2 cars at a time.')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.secondary, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Browse Cars', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isSyncing 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_sync, color: Colors.white),
            tooltip: 'Auto-scrape & Update photos',
            onPressed: _isSyncing ? null : _startOnlineSyncAndImageScrape,
          ),
          if (_comparisonList.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    final legacyList = _comparisonList.map((c) => c.toJson()).toList();
                    final mainScreen = MainScreen.globalKey.currentState;
                    if (mainScreen != null) {
                      mainScreen.navigateToCompare(legacyList);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => CarComparisonScreen(selectedCars: legacyList)));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.transparent,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(Icons.compare_arrows, color: Colors.white, size: 28),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Text('${_comparisonList.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
      body: Column(
        children: [
          if (_isSyncing)
            Container(
              color: AppColors.primary.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_syncProgressText, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          _buildSearchAndFilters(),
          Expanded(
            child: _filteredCars.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No cars found in local database.', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        if (_isSyncing)
                          const CircularProgressIndicator(color: AppColors.primary)
                        else
                          ElevatedButton.icon(
                            onPressed: _performDeepSearch,
                            icon: const Icon(Icons.auto_awesome, color: Colors.white),
                            label: Text('Deep Search AI: "${_searchController.text}"', style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadData(forceRefresh: true),
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _filteredCars.length,
                      itemBuilder: (context, index) {
                        return _buildCarCard(_filteredCars[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Myvi, X50, Civic, BYD...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Under 60k', '60k-100k', 'Above 100k'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) { 
                      if (val) {
                        setState(() => _selectedFilter = filter);
                        _applyFilters();
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filteredCars.length} models cached locally', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Text('Long-press card to compare', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarCard(CarModel car) {
    final isSelected = _comparisonList.contains(car);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode) {
            Navigator.pop(context, car.toJson());
          } else {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => CarDetailScreen(car: car.toJson())),
            ).then((_) => _loadData());
          }
        },
        onLongPress: () => _toggleComparison(car),
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
                      ? Hero(
                          tag: 'car_img_${car.id ?? car.fullName}',
                          child: CachedNetworkImage(
                            imageUrl: car.imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
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
                              child: Icon(Icons.directions_car, size: 40, color: Colors.grey),
                            ),
                          ),
                        )
                      : const Center(child: Icon(Icons.directions_car, color: Colors.grey, size: 40)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(car.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      car.isEV ? 'Electric Vehicle' : '${car.engineCC}cc ${car.fuelType}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RM ${car.price.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildTag(car.fuelType),
                        _buildTag(car.isEV ? 'EV' : '${car.fuelConsumption}L/100km'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _favouriteIds.contains(car.id) ? Icons.favorite : Icons.favorite_border,
                  color: _favouriteIds.contains(car.id) ? AppColors.accentRed : Colors.grey.shade400,
                ),
                onPressed: () => _toggleFavourite(car),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
