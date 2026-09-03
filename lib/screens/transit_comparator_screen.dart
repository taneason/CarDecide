import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';
import '../services/data_service.dart';
import '../services/api_service.dart';
import 'car_browse_screen.dart';

class TransitComparatorScreen extends StatefulWidget {
  const TransitComparatorScreen({super.key});

  @override
  State<TransitComparatorScreen> createState() => _TransitComparatorScreenState();
}

class _TransitComparatorScreenState extends State<TransitComparatorScreen> {
  final _dataService = DataService();
  final _apiService = ApiService();
  final MapController _mapController = MapController();
  
  LatLng _currentPos = const LatLng(3.1390, 101.6869); // Default KL
  LatLng? _origin;
  LatLng? _destination;
  
  double _distKM = 0.0;
  double _fuelPrice = 2.05;
  String _selectedFuelType = 'RON95 (Floating)';
  Map<String, dynamic> _liveFuelPrices = {'RON95 (Floating)': 2.05, 'RON97': 3.47, 'Diesel (Peninsular)': 3.35};
  double _consumption = 6.0;
  double _tollCost = 0.0;
  
  double _drivingCost = 0;
  double _transitCost = 0;
  int _drivingTime = 0;
  int _transitTime = 0;
  
  // New Calculation Logic State
  bool _includeFeeder = false;
  bool _transitAvailable = true;
  double _transitMinCost = 0;
  double _transitMaxCost = 0;
  String _transitLabel = "LRT / MRT / City Bus";

  bool _isLoading = true;
  List<Map<String, dynamic>> _cars = [];
  Map<String, dynamic>? _selectedCar;

  // Expansion Logic
  bool _isMapExpanded = false;

  // Map Type Logic
  bool _isSatelliteView = false;

  // Selection Context (like Google Maps)
  bool _isSelectingOrigin = false;

  // Map Tools Menu
  bool _isMenuOpen = false;

  // Search Logic
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destinationSearchController = TextEditingController();
  List<Map<String, dynamic>> _originSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  Timer? _debounce;
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originSearchController.dispose();
    _destinationSearchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Get Location
      try {
        Position? position = await _determinePosition();
        if (position != null) {
          _currentPos = LatLng(position.latitude, position.longitude);
          _origin = _currentPos;
          _originSearchController.text = "Current Location";
        }
      } catch (e) {
        debugPrint('TransitScreen: Could not get GPS location, using default KL.');
      }

      // 2. Fetch Prices & Cars
      final results = await Future.wait([
        _dataService.fetchLatestFuelPrices(),
        _dataService.fetchCarsAsMap(),
      ]);

      final fuelData = results[0] as Map<String, dynamic>;
      _cars = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          if (fuelData.isNotEmpty) {
            _liveFuelPrices = fuelData;
            _liveFuelPrices.remove('_date'); // Don't show date in dropdown
          }
          // Set default to RON95 (Floating) if available
          if (_liveFuelPrices.containsKey('RON95 (Floating)')) {
             _selectedFuelType = 'RON95 (Floating)';
          }
          _fuelPrice = (_liveFuelPrices[_selectedFuelType] as num?)?.toDouble() ?? 2.05;
          if (_cars.isNotEmpty) {
            _selectedCar = _cars[0];
            _consumption = (_selectedCar!['fuelConsumption'] as num).toDouble();
          }
          _isLoading = false;
        });
        
        _mapController.move(_currentPos, 14.0);
      }
    } catch (e) {
      debugPrint('TransitScreen Init Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  void _onSearchChanged(String query, bool isOrigin) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() {
          if (isOrigin) {
            _originSuggestions = [];
          } else {
            _destinationSuggestions = [];
          }
        });
        return;
      }

      setState(() {
        if (isOrigin) {
          _isSearchingOrigin = true;
        } else {
          _isSearchingDestination = true;
        }
      });

      final results = await _apiService.searchLocations(query);

      if (mounted) {
        setState(() {
          if (isOrigin) {
            _originSuggestions = results;
            _isSearchingOrigin = false;
          } else {
            _destinationSuggestions = results;
            _isSearchingDestination = false;
          }
        });
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion, bool isOrigin) {
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);
    final pos = LatLng(lat, lon);
    final name = suggestion['display_name'];

    setState(() {
      if (isOrigin) {
        _origin = pos;
        _originSearchController.text = name;
        _originSuggestions = [];
      } else {
        _destination = pos;
        _destinationSearchController.text = name;
        _destinationSuggestions = [];
      }
      
      _mapController.move(pos, 14.0);
      
      if (_origin != null && _destination != null) {
        _calculateRoute();
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _zoom(double delta) {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + delta);
  }

  void _resetRotation() {
    _mapController.rotate(0);
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLoading = true);
    Position? position = await _determinePosition();
    if (position != null) {
      _currentPos = LatLng(position.latitude, position.longitude);
      String? addr = await _apiService.getAddressFromCoords(_currentPos.latitude, _currentPos.longitude);
      if (mounted) {
        setState(() {
          _origin = _currentPos;
          _originSearchController.text = addr ?? "Current Location";
        });
      }
      _mapController.move(_currentPos, 14.0);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() => _isLoading = true);
    
    String? address = await _apiService.getAddressFromCoords(point.latitude, point.longitude);
    String displayAddress = address ?? "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";

    if (mounted) {
      setState(() {
        if (_isSelectingOrigin) {
          _origin = point;
          _originSearchController.text = displayAddress;
          _isSelectingOrigin = false; // Switch back to destination mode after setting origin
        } else {
          _destination = point;
          _destinationSearchController.text = displayAddress;
        }
        _isLoading = false;
        _calculateRoute();
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_origin == null || _destination == null) return;

    setState(() => _isLoading = true);

    double roadKM = await _apiService.getRoadDistance(_origin!, _destination!);

    if (mounted) {
      setState(() {
        if (roadKM > 0) {
          _distKM = roadKM;
        } else {
          double distanceInMeters = Geolocator.distanceBetween(
            _origin!.latitude, _origin!.longitude, 
            _destination!.latitude, _destination!.longitude
          );
          _distKM = (distanceInMeters / 1000) * 1.25; 
        }
        
        // 1. Driving Calculation (Unchanged)
        _tollCost = _distKM > 10 ? (_distKM - 10) * 0.15 : 0;
        _drivingCost = ((_distKM / 100) * _consumption * _fuelPrice) + _tollCost;
        _drivingTime = (_distKM * 1.5).toInt() + 5; 

        // 2. Transit Calculation (New Rules)
        
        // Rule 1: Feasibility Check (Example: Distance > 400km or extreme coordinates)
        if (_distKM > 400) {
          _transitAvailable = false;
          _transitCost = 0;
          _transitMinCost = 0;
          _transitMaxCost = 0;
        } else {
          _transitAvailable = true;
          
          if (_distKM <= 50) {
            // Rule 2: City / Short Distance
            _transitCost = 1.20 + (_distKM * 0.15);
            _transitMinCost = _transitCost;
            _transitMaxCost = _transitCost;
            _transitLabel = "LRT / MRT / City Bus";
            _transitTime = (_distKM * 3).toInt() + 15;
          } else {
            // Rule 3: Cross-State / Long Distance
            _transitMinCost = _distKM * 0.10; // Express Bus
            _transitMaxCost = _distKM * 0.20; // KTM ETS
            _transitCost = _transitMinCost; // Default for display
            _transitLabel = "Express Bus / KTM ETS";
            _transitTime = (_distKM * 1.5).toInt() + 45; // Faster multiplier for long distance highway travel
          }

          // Rule 4: First/Last Mile Add-on
          if (_includeFeeder) {
            _transitCost += 20.0;
            _transitMinCost += 20.0;
            _transitMaxCost += 20.0;
          }
        }
        
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isMapExpanded 
        ? null 
        : AppBar(
            backgroundColor: AppColors.secondary,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Drive vs. Transit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => setState(() { 
                  _origin = null; 
                  _destination = null; 
                  _distKM = 0; 
                  _originSearchController.clear(); 
                  _destinationSearchController.clear();
                  _originSuggestions = [];
                  _destinationSuggestions = [];
                }),
              )
            ],
          ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: _isMapExpanded ? 1 : 4,
                  child: Stack(
                    children: [
                      _buildMap(),
                      _buildSearchOverlay(),
                      _buildExpansionControls(),
                    ],
                  ),
                ),
                if (!_isMapExpanded)
                  Expanded(
                    flex: 6,
                    child: _buildDetailsPanel(),
                  ),
              ],
            ),
          ),
          if (_isLoading) 
            const Center(child: CircularProgressIndicator()),
          _buildInstructionOverlay(),
        ],
      ),
    );
  }

  Widget _buildExpansionControls() {
    bool showTools = _isMapExpanded || _isMenuOpen;

    final List<Widget> toolButtons = [
      _buildMapTool(
        heroTag: 'zoom_in',
        icon: Icons.add,
        onPressed: () => _zoom(1.0),
        color: AppColors.secondary,
      ),
      _buildMapTool(
        heroTag: 'zoom_out',
        icon: Icons.remove,
        onPressed: () => _zoom(-1.0),
        color: AppColors.secondary,
      ),
      _buildMapTool(
        heroTag: 'compass',
        icon: Icons.explore,
        onPressed: _resetRotation,
        color: AppColors.secondary,
      ),
      _buildMapTool(
        heroTag: 'map_type',
        icon: _isSatelliteView ? Icons.map : Icons.layers,
        onPressed: () => setState(() => _isSatelliteView = !_isSatelliteView),
        color: AppColors.secondary,
      ),
      _buildMapTool(
        heroTag: 'my_location',
        icon: Icons.my_location,
        onPressed: _moveToCurrentLocation,
        color: Colors.blue,
      ),
    ];

    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showTools) ...[
            if (_isMapExpanded)
              // Vertical stack for expanded map
              ...toolButtons.map((btn) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: btn,
              ))
            else
              // Horizontal row for collapsed map
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: toolButtons.map((btn) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: btn,
                  )).toList(),
                ),
              ),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isMapExpanded) ...[
                FloatingActionButton(
                  heroTag: 'menu_toggle',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () => setState(() => _isMenuOpen = !_isMenuOpen),
                  child: Icon(_isMenuOpen ? Icons.close : Icons.more_vert, color: AppColors.secondary),
                ),
                const SizedBox(width: 8),
              ],
              FloatingActionButton(
                heroTag: 'expand_btn',
                mini: true,
                backgroundColor: AppColors.secondary,
                onPressed: () {
                  setState(() {
                    _isMapExpanded = !_isMapExpanded;
                    if (_isMapExpanded) _isMenuOpen = false;
                  });
                },
                child: Icon(_isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
              ),
            ],
          ),
          if (_isMapExpanded) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => setState(() => _isMapExpanded = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Done Picking', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapTool({required String heroTag, required IconData icon, required VoidCallback onPressed, required Color color}) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: Colors.white,
      onPressed: onPressed,
      child: Icon(icon, color: color),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPos,
        initialZoom: 14.0,
        onTap: _onMapTap,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Rotation handled by compass
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatelliteView 
            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'my.edu.tarc.cardecide',
        ),
        MarkerLayer(
          markers: [
            if (_origin != null)
              Marker(
                point: _origin!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
              ),
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchOverlay() {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Column(
        children: [
          _buildSearchField(_originSearchController, "Search Start Point", true, _originSuggestions, _isSearchingOrigin),
          const SizedBox(height: 8),
          _buildSearchField(_destinationSearchController, "Search Destination", false, _destinationSuggestions, _isSearchingDestination),
        ],
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, bool isOrigin, List<Map<String, dynamic>> suggestions, bool isSearching) {
    bool isActive = (isOrigin && _isSelectingOrigin) || (!isOrigin && !_isSelectingOrigin);
    
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: isOrigin ? Colors.blue : Colors.red, width: 2) : Border.all(color: Colors.transparent, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: TextField(
            controller: controller,
            onChanged: (val) => _onSearchChanged(val, isOrigin),
            onTap: () {
              setState(() {
                if (isOrigin) {
                  _isSelectingOrigin = true;
                } else {
                  _isSelectingOrigin = false;
                }
              });
            },
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(isOrigin ? Icons.location_searching : Icons.location_on, color: isOrigin ? Colors.blue : Colors.red),
              suffixIcon: isSearching 
                ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                : (controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                    controller.clear();
                    setState(() {
                      if (isOrigin) { _origin = null; _originSuggestions = []; }
                      else { _destination = null; _destinationSuggestions = []; }
                      _distKM = 0;
                    });
                  }) : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(s['display_name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  onTap: () => _selectSuggestion(s, isOrigin),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCarSelector(),
            const SizedBox(height: 16),
            _buildFeederToggle(),
            const SizedBox(height: 20),
            if (_distKM > 0) ...[
              _buildStatRow('Distance', '${_distKM.toStringAsFixed(1)} km'),
              _buildStatRow('Est. Tolls', 'RM ${_tollCost.toStringAsFixed(2)}'),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(child: _buildComparisonCard('Driving', 'RM ${_drivingCost.toStringAsFixed(2)}', '$_drivingTime min', Icons.directions_car, AppColors.primary)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _transitAvailable 
                      ? _buildTransitCard()
                      : _buildUnavailableTransitCard(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInsightBanner(),
            ] else 
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Search for locations or tap on the map to set your points', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeederToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_taxi, size: 20, color: AppColors.secondary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Include Grab Feeder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Add RM 20.00 for first/last mile', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ],
          ),
          Switch(
            value: _includeFeeder,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) return AppColors.primary;
              return null;
            }),
            onChanged: (val) {
              setState(() {
                _includeFeeder = val;
                _calculateRoute();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransitCard() {
    String costDisplay;
    if (_distKM > 50) {
      costDisplay = 'RM ${_transitMinCost.toStringAsFixed(2)} - ${_transitMaxCost.toStringAsFixed(2)}';
    } else {
      costDisplay = 'RM ${_transitCost.toStringAsFixed(2)}';
    }

    return _buildComparisonCard(
      _transitLabel, 
      costDisplay, 
      '$_transitTime min', 
      _distKM > 50 ? Icons.directions_bus : Icons.train, 
      AppColors.secondary
    );
  }

  Widget _buildUnavailableTransitCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 125,
      decoration: BoxDecoration(
        color: Colors.grey.shade50, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bus_alert, color: Colors.grey, size: 28),
          SizedBox(height: 12),
          Text('No Routes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          Text('Try Driving', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCarSelector() {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CarBrowseScreen(isSelectionMode: true),
              ),
            );
            if (result != null && result is Map<String, dynamic>) {
              setState(() {
                _selectedCar = result;
                _consumption = (result['fuelConsumption'] as num?)?.toDouble() ?? 6.0;
                _calculateRoute();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedCar == null 
                        ? 'Select your car' 
                        : "${_selectedCar!['make']} ${_selectedCar!['model']} (${_selectedCar!['fuelConsumption']}L/100km)",
                    style: TextStyle(
                      color: _selectedCar == null ? Colors.grey.shade600 : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFuelType,
              isExpanded: true,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFuelType = val;
                    _fuelPrice = (_liveFuelPrices[val] as num?)?.toDouble() ?? 2.05;
                    _calculateRoute();
                  });
                }
              },
              items: _liveFuelPrices.keys.map((type) => DropdownMenuItem(
                value: type, 
                child: Text("$type (RM ${(_liveFuelPrices[type] as num?)?.toStringAsFixed(2)})")
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(String title, String cost, String time, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade100), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(cost, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInsightBanner() {
    if (!_transitAvailable) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.blue.shade100)
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'No direct public transit found for this route. Driving is recommended.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ),
          ],
        ),
      );
    }

    bool drivingBetter;
    double diff;
    String message;

    if (_distKM > 50) {
      // For long distance, compare driving against transit range
      if (_drivingCost < _transitMinCost) {
        drivingBetter = true;
        diff = _transitMinCost - _drivingCost;
        message = 'Driving is RM ${diff.toStringAsFixed(2)} cheaper than the cheapest transit!';
      } else if (_drivingCost > _transitMaxCost) {
        drivingBetter = false;
        diff = _drivingCost - _transitMaxCost;
        message = 'Public transit is at least RM ${diff.toStringAsFixed(2)} cheaper than driving!';
      } else {
        drivingBetter = false;
        message = 'Public transit costs are comparable to driving for this trip.';
      }
    } else {
      // For short distance, compare directly
      drivingBetter = _drivingCost < _transitCost;
      diff = (_drivingCost - _transitCost).abs();
      message = drivingBetter 
        ? 'Driving is RM ${diff.toStringAsFixed(2)} cheaper for this trip.'
        : 'Public transit is RM ${diff.toStringAsFixed(2)} cheaper for this trip!';
    }

    Color bannerColor = drivingBetter ? Colors.orange : Colors.green;
    Color textColor = drivingBetter ? Colors.orange.shade900 : Colors.green.shade900;
    Color bgColor = drivingBetter ? Colors.orange.shade50 : Colors.green.shade50;
    Color borderColor = drivingBetter ? Colors.orange.shade100 : Colors.green.shade100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: borderColor)
      ),
      child: Row(
        children: [
          Icon(drivingBetter ? Icons.info_outline : Icons.eco, color: bannerColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionOverlay() {
    if (_origin != null && _destination != null) return const SizedBox.shrink();
    // Hide instruction if suggestions are showing to avoid cluttered UI
    if (_originSuggestions.isNotEmpty || _destinationSuggestions.isNotEmpty) return const SizedBox.shrink();
    
    String message = _isSelectingOrigin ? '📍 Tap to set Start Point' : '🏁 Tap to set Destination';
    
    return Positioned(
      top: 150, // Pushed further down as requested
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.9), 
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)]
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
