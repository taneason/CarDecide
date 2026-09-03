import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class DecisionSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cars;

  const DecisionSummaryScreen({super.key, required this.cars});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Decision Summary'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost of Ownership Summary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estimated monthly commitment for your selected cars.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...cars.map((car) => _buildSummaryCard(car)).toList(),
            const SizedBox(height: 32),
            _buildPublicTransportComparison(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> car) {
    // Basic calculation for summary
    double price = (car['price'] as num).toDouble();
    double monthlyLoan = (price * 0.9 * 1.03 * 7) / (7 * 12); // Mock: 90% loan, 3% interest, 7 years
    double monthlyFuel = car['isEV'] ? 80 : 350; // Mock estimates
    double total = monthlyLoan + monthlyFuel + 20; // + roadtax/misc

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${car['make']} ${car['model']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (car['isEV'])
                const Icon(Icons.eco, color: AppColors.accentGreen),
            ],
          ),
          const Divider(height: 24),
          _buildCostRow('Monthly Instalment', 'RM ${monthlyLoan.toStringAsFixed(0)}'),
          _buildCostRow('Est. Fuel/Energy', 'RM ${monthlyFuel.toStringAsFixed(0)}'),
          _buildCostRow('Maintenance/Misc', 'RM 50'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Monthly Cost', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('RM ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPublicTransportComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen),
      ),
      child: Column(
        children: [
          const Icon(Icons.train, color: AppColors.accentGreen, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Public Transport Alternative',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accentGreen),
          ),
          const SizedBox(height: 8),
          const Text(
            'A monthly My50 pass (RM50) could save you over RM1,000 per month compared to car ownership.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
