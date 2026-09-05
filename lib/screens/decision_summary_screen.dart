import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class DecisionSummaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> cars;

  const DecisionSummaryScreen({super.key, required this.cars});

  bool _isCarEV(Map<String, dynamic> car) {
    return car['isEV'] == true ||
        car['is_ev'] == true ||
        (car['fuelType']?.toString().toLowerCase().contains('ev') ?? false) ||
        (car['fuel_type']?.toString().toLowerCase().contains('ev') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Decision Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost of Ownership Summary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estimated monthly commitment for your selected vehicles (1,500 km/mo).',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...cars.map((car) => _buildSummaryCard(car)),
            const SizedBox(height: 24),
            _buildPublicTransportComparison(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> car) {
    final bool isEV = _isCarEV(car);
    final double price = (car['price'] as num?)?.toDouble() ?? 0.0;
    final double principal = price * 0.9;
    final double monthlyLoan = price > 0 ? ((principal + principal * 0.035 * 9) / (9 * 12)) : 0.0;
    final double cons = (car['fuelConsumption'] ?? car['fuel_consumption'] as num?)?.toDouble() ?? (isEV ? 15.0 : 6.0);
    final double monthlyEnergy = isEV
        ? (1500.0 / 100.0) * cons * 0.57
        : (1500.0 / 100.0) * cons * 2.05;
    final double maintenance = isEV ? 40.0 : 80.0;
    final double total = monthlyLoan + monthlyEnergy + maintenance;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${car['make'] ?? ''} ${car['model'] ?? ''}'.trim(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              if (isEV)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF059669)),
                      SizedBox(width: 2),
                      Text('EV', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    car['fuelType']?.toString() ?? 'Petrol',
                    style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          _buildCostRow('Monthly Loan (9 yrs)', 'RM ${monthlyLoan.toStringAsFixed(0)}'),
          _buildCostRow(
            isEV ? 'Est. Charging (TNB Home)' : 'Est. Fuel (RON95)',
            'RM ${monthlyEnergy.toStringAsFixed(0)}',
          ),
          _buildCostRow(
            'Est. Maintenance & Misc',
            'RM ${maintenance.toStringAsFixed(0)}',
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Monthly Commitment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                'RM ${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPublicTransportComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.train_rounded, color: AppColors.accentGreen, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Public Transport Alternative',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accentGreen),
          ),
          const SizedBox(height: 8),
          const Text(
            'A monthly My50 unlimited travel pass (RM50) could save you over RM1,000 per month compared to personal car ownership.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
