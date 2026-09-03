import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchFavouritesCount();
  }

  void refresh() {
    _fetchProfile();
    _fetchFavouritesCount();
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

    // If sheet returned true (saved successfully), refresh the page
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

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        title: const Text('Account Profile', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar & Header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary,
                          backgroundImage: _profileData?['avatar_url'] != null 
                              ? NetworkImage(_profileData!['avatar_url']) 
                              : null,
                          child: _profileData?['avatar_url'] == null
                              ? Icon(
                                  user == null ? Icons.person_outline : Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user == null ? 'Guest User' : (_profileData?['full_name'] ?? 'Car Enthusiast'),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (user != null)
                          Text(
                            user.email ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Stats Row
                  Row(
                    children: [
                      _buildStatItem(
                        'Saved Cars', 
                        user == null ? '0' : _favouriteCount.toString(), 
                        Icons.favorite_border,
                        onTap: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const FavouritesScreen()),
                            ).then((_) => _fetchFavouritesCount());
                          }
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  

                  if (user != null) ...[
                    _buildSectionHeader('Account'),
                    _buildSettingItem(
                      Icons.lock_outline, 
                      'Change Password', 
                      '',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                  
                  // Action Buttons
                  if (user != null)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _showEditProfileSheet,
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        label: const Text('Edit Profile', style: TextStyle(color: Colors.white),),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(user == null ? Icons.login : Icons.logout, color: user == null ? AppColors.primary : AppColors.accentRed),
                      label: Text(user == null ? 'Sign In / Register' : 'Sign Out', style: TextStyle(color: user == null ? AppColors.primary : AppColors.accentRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: user == null ? AppColors.primary : AppColors.accentRed),
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

  Widget _buildStatItem(String label, String value, IconData icon, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String trailing, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(trailing, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Separate StatefulWidget for the Edit Profile bottom sheet ────────────────
// Using a dedicated widget avoids the GlobalKey conflict that occurs when
// StatefulBuilder triggers setState while a Form key is still registered.
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

      // 1. Upload new avatar if selected
      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last;
        final fileName = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        await _supabase.storage.from('avatars').upload(fileName, _selectedImage!);
        newAvatarUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // 2. Update profile data
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
    // Determine which image to show
    ImageProvider? currentAvatar;
    if (_selectedImage != null) {
      currentAvatar = FileImage(_selectedImage!);
    } else if (widget.avatarUrl != null) {
      currentAvatar = NetworkImage(widget.avatarUrl!);
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: MediaQuery.of(context).padding.top + 20, // max height safety
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
                // Handle bar
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

              // Avatar preview (Tap to change)
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

              // Display name field
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

              // Save button
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
