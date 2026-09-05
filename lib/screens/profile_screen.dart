import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../constants/app_constants.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'favourites_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  int _favouriteCount = 0;
  String _preferredFuel = 'RON95 (Floating)';

  @override
  void initState() {
    super.initState();
    _loadPreferredFuel();
    _fetchProfile();
    _fetchFavouritesCount();
  }

  void refresh() {
    _loadPreferredFuel();
    _fetchProfile();
    _fetchFavouritesCount();
  }

  Future<void> _loadPreferredFuel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('preferred_fuel');
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _preferredFuel = saved);
      }
    } catch (e) {
      debugPrint('Error loading preferred fuel: $e');
    }
  }

  Future<void> _savePreferredFuel(String fuel) async {
    setState(() => _preferredFuel = fuel);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_fuel', fuel);
    } catch (e) {
      debugPrint('Error saving local fuel preference: $e');
    }

    final user = _authService.currentUser;
    if (user != null) {
      try {
        await _supabase.from('profiles').update({'preferred_fuel': fuel}).eq('id', user.id);
      } catch (e) {
        debugPrint('Error syncing preferred fuel to cloud: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preferred fuel set to $fuel'),
          backgroundColor: AppColors.accentGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });

        if (data['preferred_fuel'] != null && (data['preferred_fuel'] as String).isNotEmpty) {
          final cloudFuel = data['preferred_fuel'] as String;
          setState(() => _preferredFuel = cloudFuel);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('preferred_fuel', cloudFuel);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchFavouritesCount() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('favourite_indicators')
          .select('id')
          .eq('user_id', user.id);
      
      if (mounted) {
        setState(() {
          _favouriteCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching favourites: $e');
    }
  }

  Future<void> _showEditProfileSheet() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initialName: _profileData?['full_name'] ?? '',
        avatarUrl: _profileData?['avatar_url'],
        email: user.email ?? '',
        userId: user.id,
      ),
    );

    if (result == true && mounted) {
      await _fetchProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  String _getShortFuelName(String fuel) {
    if (fuel.contains('BUDI 95')) return 'BUDI 95';
    if (fuel.contains('SKPS')) return 'SKPS 95';
    if (fuel.contains('Floating')) return 'RON95';
    if (fuel.contains('97')) return 'RON97';
    if (fuel.contains('SKDS')) return 'SKDS Diesel';
    if (fuel.contains('Diesel (BUDI)')) return 'BUDI Diesel';
    if (fuel.contains('Sbh/Swk')) return 'East Msia Diesel';
    if (fuel.contains('Diesel')) return 'Diesel';
    if (fuel.contains('Electric') || fuel.contains('EV')) return 'EV Electric';
    return fuel;
  }

  IconData _getFuelIcon(String fuel) {
    if (fuel.contains('Electric') || fuel.contains('EV')) return Icons.bolt_rounded;
    if (fuel.contains('Diesel')) return Icons.local_shipping_outlined;
    return Icons.local_gas_station_rounded;
  }

  void _showFuelPreferenceSheet() {
    final fuelOptions = [
      {
        'key': 'RON95 (Floating)',
        'title': 'RON95 (Floating Rate)',
        'subtitle': 'Unsubsidised market pricing for private vehicles',
        'icon': Icons.local_gas_station_rounded,
      },
      {
        'key': 'RON95 (BUDI 95)',
        'title': 'RON95 (BUDI 95 Subsidy)',
        'subtitle': 'Targeted fuel subsidy scheme for eligible Malaysians',
        'icon': Icons.verified_user_outlined,
      },
      {
        'key': 'RON95 (SKPS)',
        'title': 'RON95 (SKPS Transport)',
        'subtitle': 'Subsidised rate for public land transport',
        'icon': Icons.directions_bus_outlined,
      },
      {
        'key': 'RON97',
        'title': 'RON97 Premium',
        'subtitle': 'High octane performance euro 4M / 5 petrol',
        'icon': Icons.speed_rounded,
      },
      {
        'key': 'Diesel (Peninsular)',
        'title': 'Diesel (Peninsular Euro 5)',
        'subtitle': 'Euro 5 standard diesel for Peninsular Malaysia',
        'icon': Icons.local_shipping_outlined,
      },
      {
        'key': 'Diesel (Sbh/Swk)',
        'title': 'Diesel (Sabah & Sarawak)',
        'subtitle': 'Subsidised diesel rate for East Malaysia',
        'icon': Icons.terrain_rounded,
      },
      {
        'key': 'Diesel (SKDS)',
        'title': 'Diesel (SKDS Fleet)',
        'subtitle': 'Targeted fleet subsidy for logistics and transport',
        'icon': Icons.airport_shuttle_outlined,
      },
      {
        'key': 'Diesel (BUDI)',
        'title': 'Diesel (BUDI Madani)',
        'subtitle': 'Direct citizen subsidy rate under BUDI Madani',
        'icon': Icons.card_giftcard_rounded,
      },
      {
        'key': 'Electric (EV)',
        'title': 'Electric Vehicle (EV)',
        'subtitle': 'Zero direct emissions & domestic / DC fast charging',
        'icon': Icons.bolt_rounded,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_gas_station_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preferred Fuel Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Used as default in calculations & transit comparisons', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...fuelOptions.map((opt) {
                final isSelected = _preferredFuel == opt['key'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(ctx);
                      _savePreferredFuel(opt['key'] as String);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            opt['icon'] as IconData,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt['title'] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt['subtitle'] as String,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                          else
                            Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.directions_car_filled_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('About CarDecide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CarDecide Malaysia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 4),
            Text('Version 1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'Your comprehensive smart automotive & transit companion in Malaysia. Real-time fuel price monitoring, ownership calculations, and AI-driven car advisory.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: const Text('Account Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.secondary,
                            backgroundImage: _profileData?['avatar_url'] != null 
                                ? NetworkImage(_profileData!['avatar_url']) 
                                : null,
                            child: _profileData?['avatar_url'] == null
                                ? Icon(
                                    user == null ? Icons.person_outline : Icons.person,
                                    size: 46,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user == null ? 'Guest User' : (_profileData?['full_name'] ?? 'Car Enthusiast'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (user != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildStatItem(
                        label: 'Saved Cars',
                        value: user == null ? '0' : _favouriteCount.toString(),
                        subtitle: 'View shortlist',
                        icon: Icons.favorite_rounded,
                        iconColor: AppColors.accentRed,
                        onTap: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavouritesScreen()),
                            ).then((_) => _fetchFavouritesCount());
                          }
                        },
                      ),
                      const SizedBox(width: 14),
                      _buildStatItem(
                        label: 'Preferred Fuel',
                        value: _getShortFuelName(_preferredFuel),
                        subtitle: 'Tap to change',
                        icon: _getFuelIcon(_preferredFuel),
                        iconColor: AppColors.primary,
                        onTap: _showFuelPreferenceSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Account & Security'),
                  _buildCardSection([
                    if (user != null) ...[
                      _buildSettingTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Change Password',
                        trailing: '',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                      _buildDivider(),
                    ],
                    _buildSettingTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Saved Vehicles',
                      trailing: '${user == null ? 0 : _favouriteCount} cars',
                      onTap: () {
                        if (user != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FavouritesScreen()),
                          ).then((_) => _fetchFavouritesCount());
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Preferences'),
                  _buildCardSection([
                    _buildSettingTile(
                      icon: Icons.local_gas_station_outlined,
                      title: 'Default Fuel Preference',
                      trailing: _getShortFuelName(_preferredFuel),
                      trailingColor: AppColors.primary,
                      onTap: _showFuelPreferenceSheet,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionHeader('About & Support'),
                  _buildCardSection([
                    _buildSettingTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About CarDecide',
                      trailing: 'v1.0.0',
                      onTap: _showAboutDialog,
                    ),
                  ]),
                  const SizedBox(height: 28),
                  if (user != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _showEditProfileSheet,
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(user == null ? Icons.login_rounded : Icons.logout_rounded, color: user == null ? AppColors.primary : AppColors.accentRed, size: 20),
                      label: Text(
                        user == null ? 'Sign In / Register' : 'Sign Out',
                        style: TextStyle(color: user == null ? AppColors.primary : AppColors.accentRed, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: (user == null ? AppColors.primary : AppColors.accentRed).withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildCardSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String trailing,
    Color? trailingColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
            ),
            if (trailing.isNotEmpty) ...[
              Text(
                trailing,
                style: TextStyle(
                  color: trailingColor ?? AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: trailingColor != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, indent: 52, endIndent: 16, color: Colors.grey.shade100);
  }
}


class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String? avatarUrl;
  final String email;
  final String userId;

  const _EditProfileSheet({
    required this.initialName,
    required this.avatarUrl,
    required this.email,
    required this.userId,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  late final TextEditingController _nameController;
  final _passwordController = TextEditingController();
  
  bool _isSaving = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Avatar', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
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

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      String? newAvatarUrl = widget.avatarUrl;

      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last;
        final fileName = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        await _supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        newAvatarUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        if (_selectedImage != null) 'avatar_url': newAvatarUrl,
      }).eq('id', widget.userId);

      if (mounted) nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e\n(Ensure "avatars" storage bucket exists and policies allow uploads)'),
            backgroundColor: AppColors.accentRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? currentAvatar;
    if (_selectedImage != null) {
      currentAvatar = FileImage(_selectedImage!);
    } else if (widget.avatarUrl != null) {
      currentAvatar = NetworkImage(widget.avatarUrl!);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: MediaQuery.of(context).padding.top + 20,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 20),
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

              Center(
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(48),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primary,
                        backgroundImage: currentAvatar,
                        child: currentAvatar == null
                            ? const Icon(Icons.person, size: 48, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  widget.email,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Display Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.secondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentRed, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Display name cannot be empty';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Save Changes',
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
        ),
      ),
    );
  }
}
