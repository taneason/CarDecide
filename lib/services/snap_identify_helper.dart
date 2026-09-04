import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_constants.dart';
import '../models/car_model.dart';
import 'dynamic_fetch_service.dart';
import '../screens/car_detail_screen.dart';

class SnapIdentifyHelper {
  static Future<void> handleSnapIdentify(BuildContext context) async {
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
    if (image.name.toLowerCase().endsWith('.png')) {
      mimeType = 'image/png';
    } else if (image.name.toLowerCase().endsWith('.webp')) {
      mimeType = 'image/webp';
    }

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
        SnackBar(content: Text('Identified as  !'), backgroundColor: AppColors.accentGreen),
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
}
