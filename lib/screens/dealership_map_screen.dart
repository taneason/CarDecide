import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../services/api_service.dart';

class DealershipMapScreen extends StatefulWidget {
  const DealershipMapScreen({super.key});

  @override
  State<DealershipMapScreen> createState() => _DealershipMapScreenState();
}

class _DealershipMapScreenState extends State<DealershipMapScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  // The center used to load dealerships (either user location or searched place)
  LatLng _searchCenter = const LatLng(3.1390, 101.6869);
  // Actual user GPS location (blue dot)
  LatLng? _userLocation;

  bool _isLoadingLocation = true;
  bool _isLoadingDealers = false;
  bool _isSatelliteView = false;
  bool _isSearching = false;

  List<Map<String, dynamic>> _dealerships = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  String? _searchedPlaceName; // Label shown under search bar

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { _loadDealerships(); return; }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) { _loadDealerships(); return; }
    }
    if (permission == LocationPermission.deniedForever) { _loadDealerships(); return; }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _searchCenter = _userLocation!;
          _isLoadingLocation = false;
        });
        _mapController.move(_searchCenter, 13.0);
        _loadDealerships();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _loadDealerships();
      }
    }
  }

  // ── Dealership loading ────────────────────────────────────────────────────

  Future<void> _loadDealerships() async {
    setState(() {
      _isLoadingLocation = false;
      _isLoadingDealers = true;
    });

    final dealers = await _apiService.fetchNearbyDealerships(
      _searchCenter.latitude,
      _searchCenter.longitude,
      radius: 5000,
    );

    if (mounted) {
      setState(() {
        _dealerships = dealers;
        _isLoadingDealers = false;
      });
    }
  }

  // ── Geocoding search (Nominatim, same as transit comparator) ─────────────

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=my',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'CarDecide/1.0',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;
        setState(() {
          _searchSuggestions = results.map((r) => {
            'name': r['display_name'],
            'lat': double.parse(r['lat']),
            'lng': double.parse(r['lon']),
          }).toList();
        });
      }
    } catch (_) {
      // silent fail
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final newCenter = LatLng(suggestion['lat'], suggestion['lng']);
    // Shorten the displayed name (first two comma-separated parts)
    final parts = (suggestion['name'] as String).split(',');
    final shortName = parts.take(2).join(',').trim();

    setState(() {
      _searchCenter = newCenter;
      _searchedPlaceName = shortName;
      _searchSuggestions = [];
      _searchController.text = shortName;
    });

    _mapController.move(_searchCenter, 13.0);
    _loadDealerships();
    FocusScope.of(context).unfocus();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchSuggestions = [];
      _searchedPlaceName = null;
      // Reset to user location if available
      if (_userLocation != null) {
        _searchCenter = _userLocation!;
        _mapController.move(_searchCenter, 13.0);
        _loadDealerships();
      }
    });
  }

  // ── Google Maps deep link ─────────────────────────────────────────────────

  Future<void> _openInGoogleMaps(Map<String, dynamic> dealer) async {
    final lat = dealer['lat'];
    final lng = dealer['lng'];
    final name = Uri.encodeComponent(dealer['name']);

    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    final Uri webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$name');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps app.')),
        );
      }
    }
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  void _showDealerInfo(Map<String, dynamic> dealer) {
    final bool hasAddress = dealer['location'] != null &&
        dealer['location'] != 'Address not available';
    final bool hasPhone =
        dealer['phone'] != null && dealer['phone'] != 'Not provided';
    final bool hasHours =
        dealer['hours'] != null && dealer['hours'] != 'Not provided';
    final bool hasWebsite = dealer['website'] != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.secondary, Color(0xFF2C3E6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.storefront, size: 56, color: Colors.white24),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Powered by OpenStreetMap',
                                  style: TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dealer['name'],
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dealer['brand'],
                        style: const TextStyle(
                            color: AppColors.secondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (hasAddress) ...[
                      _buildInfoRow(Icons.location_on_outlined, dealer['location']),
                      const SizedBox(height: 12),
                    ],
                    if (hasPhone) ...[
                      _buildInfoRow(Icons.phone_outlined, dealer['phone']),
                      const SizedBox(height: 12),
                    ],
                    if (hasHours) ...[
                      _buildInfoRow(Icons.access_time_outlined, dealer['hours']),
                      const SizedBox(height: 12),
                    ],
                    if (hasWebsite) ...[
                      _buildInfoRow(Icons.language_outlined, dealer['website']),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tips_and_updates_outlined,
                              size: 16, color: Color(0xFF1A73E8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap below to view up-to-date details, photos & reviews on Google Maps.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.secondary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Close',
                                style: TextStyle(
                                    color: AppColors.secondary, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _openInGoogleMaps(dealer),
                            icon: const Icon(Icons.map, color: Colors.white, size: 18),
                            label: const Text('Open in Google Maps',
                                style: TextStyle(color: Colors.white, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _zoom(double delta) {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + delta);
  }

  void _resetRotation() {
    _mapController.rotate(0);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildMapTool({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: Colors.white,
      onPressed: onPressed,
      child: Icon(icon, color: color),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.secondary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Nearby Dealerships',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _searchCenter,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, __) {
                if (_searchSuggestions.isNotEmpty) {
                  setState(() => _searchSuggestions = []);
                }
              },
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
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.blue, size: 22),
                      ),
                    ),
                  if (_searchedPlaceName != null)
                    Marker(
                      point: _searchCenter,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.place,
                          color: Colors.deepPurple, size: 40),
                    ),
                  ..._dealerships.map((dealer) {
                    return Marker(
                      point: LatLng(dealer['lat'], dealer['lng']),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _showDealerInfo(dealer),
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 38),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // ── Search bar overlay ────────────────────────────────────────
          Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchLocation,
                      decoration: InputDecoration(
                        hintText: 'Search a location...',
                        prefixIcon:
                            const Icon(Icons.search, color: AppColors.secondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: _clearSearch,
                              )
                            : _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_searchSuggestions.isNotEmpty)
                    Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchSuggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _searchSuggestions[i];
                          final parts =
                              (s['name'] as String).split(',');
                          final title = parts.first.trim();
                          final subtitle =
                              parts.skip(1).take(2).join(',').trim();
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined,
                                color: AppColors.secondary, size: 20),
                            title: Text(title,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: subtitle.isNotEmpty
                                ? Text(subtitle,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600))
                                : null,
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
                    ),
                  if (_searchedPlaceName != null &&
                      _searchSuggestions.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Showing dealerships near: $_searchedPlaceName',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // ── Map tool buttons (identical layout to Transit Comparator) ────
          _buildMapControls(),

          // ── Loading overlay ───────────────────────────────────────────────
          if (_isLoadingLocation || _isLoadingDealers)
            Center(
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.secondary)),
                      const SizedBox(width: 16),
                      Text(
                        _isLoadingLocation
                            ? 'Finding your location...'
                            : 'Searching for dealerships...',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Map controls widget (always visible, no toggle/fullscreen) ──────────
  Widget _buildMapControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapTool(
            heroTag: 'zoom_in',
            icon: Icons.add,
            onPressed: () => _zoom(1.0),
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          _buildMapTool(
            heroTag: 'zoom_out',
            icon: Icons.remove,
            onPressed: () => _zoom(-1.0),
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          _buildMapTool(
            heroTag: 'compass',
            icon: Icons.explore,
            onPressed: _resetRotation,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          _buildMapTool(
            heroTag: 'map_type',
            icon: _isSatelliteView ? Icons.map : Icons.layers,
            onPressed: () =>
                setState(() => _isSatelliteView = !_isSatelliteView),
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          _buildMapTool(
            heroTag: 'my_location',
            icon: Icons.my_location,
            onPressed: () {
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 13.0);
              }
            },
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildMapTool(
            heroTag: 'refresh_dealers',
            icon: Icons.refresh,
            onPressed: _loadDealerships,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

