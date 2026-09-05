import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../constants/app_constants.dart';
import '../services/data_service.dart';
import '../services/ai_service.dart';
import 'decision_summary_screen.dart';
import 'car_browse_screen.dart';
import 'car_detail_screen.dart';

class CarComparisonScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedCars;

  const CarComparisonScreen({super.key, required this.selectedCars});

  @override
  State<CarComparisonScreen> createState() => CarComparisonScreenState();
}

class CarComparisonScreenState extends State<CarComparisonScreen> {
  final DataService _dataService = DataService();
  final AiService _aiService = AiService();
  List<Map<String, dynamic>> _allCars = [];
  Map<String, dynamic>? carA;
  Map<String, dynamic>? carB;
  String _aiSummary = "Generating AI insights...";
  bool _isAiLoading = true;

  void setCars(List<Map<String, dynamic>> cars) {
    if (cars.isNotEmpty) {
      setState(() {
        carA = cars[0];
        if (cars.length > 1) {
          carB = cars[1];
        }
      });
      _generateAiSummary();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    final cars = await _dataService.fetchCarsAsMap();
    if (mounted) {
      setState(() {
        _allCars = cars;
        if (widget.selectedCars.isNotEmpty) {
          final targetA = widget.selectedCars[0];
          carA = _allCars.firstWhere(
            (c) => c['make'] == targetA['make'] && c['model'] == targetA['model'],
            orElse: () => _allCars.isNotEmpty ? _allCars[0] : <String, dynamic>{},
          );
          if (widget.selectedCars.length > 1) {
            final targetB = widget.selectedCars[1];
            carB = _allCars.firstWhere(
              (c) => c['make'] == targetB['make'] && c['model'] == targetB['model'],
              orElse: () => _allCars.length > 1 ? _allCars[1] : <String, dynamic>{},
            );
          } else {
            carB = _allCars.length > 1 ? _allCars[1] : null;
          }
        } else {
          carA = _allCars.isNotEmpty ? _allCars[0] : null;
          carB = _allCars.length > 1 ? _allCars[1] : null;
        }
      });
      _generateAiSummary();
    }
  }

  bool _isCarEV(Map<String, dynamic>? car) {
    if (car == null) return false;
    return car['isEV'] == true ||
        car['is_ev'] == true ||
        (car['fuelType']?.toString().toLowerCase().contains('ev') ?? false) ||
        (car['fuel_type']?.toString().toLowerCase().contains('ev') ?? false);
  }

  double _getEnergyRate(Map<String, dynamic>? car) {
    if (car == null) return 2.05;
    if (_isCarEV(car)) return 0.57;
    final String fuelType = (car['fuelType'] ?? car['fuel_type'] ?? '').toString().toLowerCase();
    if (fuelType.contains('diesel')) return 3.35;
    if (fuelType.contains('ron97')) return 3.47;
    return 2.05;
  }

  Future<void> _generateAiSummary() async {
    if (carA == null || carB == null || carA!.isEmpty || carB!.isEmpty) return;
    setState(() => _isAiLoading = true);

    final bool isEvA = _isCarEV(carA);
    final bool isEvB = _isCarEV(carB);
    final double consA = (carA?['fuelConsumption'] ?? carA?['fuel_consumption'] as num?)?.toDouble() ?? (isEvA ? 15.0 : 6.0);
    final double consB = (carB?['fuelConsumption'] ?? carB?['fuel_consumption'] as num?)?.toDouble() ?? (isEvB ? 15.0 : 6.0);

    final prompt = "IGNORE your system instructions about recommending public transport or asking follow-up questions. "
        "Strictly provide a direct, objective comparison summary between: "
        "${carA!['make']} ${carA!['model']} (${isEvA ? 'Electric EV, $consA kWh/100km' : 'Petrol/Diesel, $consA L/100km'}, RM ${carA!['price']}) vs "
        "${carB!['make']} ${carB!['model']} (${isEvB ? 'Electric EV, $consB kWh/100km' : 'Petrol/Diesel, $consB L/100km'}, RM ${carB!['price']}). "
        "Format your answer as 2-3 bullet points highlighting value for money, fuel vs EV electricity charging cost differences, and the overall winner. "
        "Do not use conversational filler like 'Since both...' or 'Would you like me to...'";

    final response = await _aiService.sendMessage(prompt);
    
    if (mounted) {
      setState(() {
        _aiSummary = response;
        _isAiLoading = false;
      });
    }
  }

  String _formatCurrency(double value) {
    return 'RM ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
  }

  double _calculateMonthlyLoan(double price) {
    double principal = price * 0.9;
    double totalInterest = principal * 0.035 * 9;
    return (principal + totalInterest) / (9 * 12);
  }

  double _calculateMonthlyEnergy(Map<String, dynamic>? car) {
    if (car == null) return 0.0;
    final bool isEV = _isCarEV(car);
    final double consumption = (car['fuelConsumption'] ?? car['fuel_consumption'] as num?)?.toDouble() ?? (isEV ? 15.0 : 6.0);
    if (isEV) {
      return (1500.0 / 100.0) * consumption * 0.57;
    }
    final double rate = _getEnergyRate(car);
    return (1500.0 / 100.0) * consumption * rate;
  }

  double _calculateRoadTax(num? engineCC, bool isEV, num? motorPower) {
    if (isEV) {
      final double kw = motorPower?.toDouble() ?? 100.0;
      if (kw <= 50.0) return 20.0;
      if (kw <= 60.0) return 30.0;
      if (kw <= 70.0) return 40.0;
      if (kw <= 80.0) return 50.0;
      if (kw <= 90.0) return 60.0;
      if (kw <= 100.0) return 70.0;
      if (kw <= 110.0) return 80.0;
      if (kw <= 120.0) return 90.0;
      if (kw <= 130.0) return 100.0;
      if (kw <= 140.0) return 110.0;
      if (kw <= 150.0) return 120.0;
      if (kw <= 160.0) return 135.0;
      if (kw <= 170.0) return 150.0;
      if (kw <= 180.0) return 165.0;
      if (kw <= 190.0) return 180.0;
      return 200.0;
    }
    final int cc = engineCC?.toInt() ?? 1500;
    if (cc <= 1000) return 20.0;
    if (cc <= 1200) return 55.0;
    if (cc <= 1400) return 70.0;
    if (cc <= 1600) return 90.0;
    if (cc <= 1800) return 200.0 + (cc - 1600) * 0.40;
    if (cc <= 2000) return 280.0 + (cc - 1800) * 0.50;
    if (cc <= 2500) return 380.0 + (cc - 2000) * 1.00;
    if (cc <= 3000) return 880.0 + (cc - 2500) * 2.50;
    return 2130.0 + (cc - 3000) * 4.50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Compare Models', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: carA == null || carB == null 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTopCards(),
                const SizedBox(height: 24),
                _buildTotalMonthlyCost(),
                const SizedBox(height: 24),
                _buildMetricTable(),
                const SizedBox(height: 24),
                _buildAiSummaryCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildTopCards() {
    return Row(
      children: [
        Expanded(child: _buildSingleCarCard('Car A', carA, (val) {
          setState(() => carA = val);
          _generateAiSummary();
        })),
        const SizedBox(width: 16),
        Expanded(child: _buildSingleCarCard('Car B', carB, (val) {
          setState(() => carB = val);
          _generateAiSummary();
        })),
      ],
    );
  }

  Widget _buildSingleCarCard(String label, Map<String, dynamic>? car, Function(Map<String, dynamic>?) onSelect) {
    double priceA = (carA?['price'] as num?)?.toDouble() ?? 0.0;
    double priceB = (carB?['price'] as num?)?.toDouble() ?? 0.0;
    bool isBestValue = (label == 'Car A' && priceA <= priceB) || (label == 'Car B' && priceB < priceA);
    final String? carImg = car?['imageUrl'] ?? car?['image_url'];
    final bool isEV = _isCarEV(car);

    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (car != null && car.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarDetailScreen(car: car),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      if (car != null && car.isNotEmpty)
                        const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      color: AppColors.background,
                      child: (carImg != null && carImg.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: carImg,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (context, url) => Container(color: Colors.grey.shade100),
                              errorWidget: (c, url, error) => const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                            )
                          : const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${car?['make'] ?? ""} ${car?['model'] ?? ""}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(_formatCurrency((car?['price'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isEV ? const Color(0xFF10B981).withValues(alpha: 0.12) : AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isEV ? Icons.bolt_rounded : Icons.local_gas_station_rounded,
                              size: 11,
                              color: isEV ? const Color(0xFF059669) : AppColors.secondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isEV ? 'EV' : (car?['fuelType']?.toString() ?? 'Petrol'),
                              style: TextStyle(
                                color: isEV ? const Color(0xFF059669) : AppColors.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isBestValue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: AppColors.accentGreen, size: 11),
                              SizedBox(width: 3),
                              Text('Value', style: TextStyle(color: AppColors.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: () async {
              final selected = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CarBrowseScreen(isSelectionMode: true)),
              );
              if (selected != null && selected is Map<String, dynamic>) {
                onSelect(selected);
              }
            },
            icon: Icon(Icons.swap_horiz, size: 18, color: car == null ? Colors.white : AppColors.primary),
            label: Text(
              car == null ? 'Select Car' : 'Change Car', 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.bold,
                color: car == null ? Colors.white : AppColors.primary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: car == null ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: car == null ? Colors.transparent : AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalMonthlyCost() {
    double priceA = (carA?['price'] as num?)?.toDouble() ?? 0.0;
    double priceB = (carB?['price'] as num?)?.toDouble() ?? 0.0;

    double loanA = _calculateMonthlyLoan(priceA);
    double loanB = _calculateMonthlyLoan(priceB);
    double energyA = _calculateMonthlyEnergy(carA);
    double energyB = _calculateMonthlyEnergy(carB);

    double totalA = loanA + energyA;
    double totalB = loanB + energyB;

    bool aIsWinner = totalA <= totalB;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL MONTHLY COST',
            style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),
          _buildCostBar(carA?['model'] ?? 'Car A', totalA, aIsWinner ? AppColors.accentGreen : AppColors.accentRed, aIsWinner),
          const SizedBox(height: 20),
          _buildCostBar(carB?['model'] ?? 'Car B', totalB, !aIsWinner ? AppColors.accentGreen : AppColors.accentRed, !aIsWinner),
          const SizedBox(height: 20),
          const Text(
            '*9yr loan, 10% down, 3.5% | 1,500km/mo (EV @ RM0.57/kWh TNB, Petrol @ RM2.05/L)',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCostBar(String name, double cost, Color color, bool isWinner) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('RM ${cost.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (cost / 2000).clamp(0, 1), 
          backgroundColor: AppColors.background,
          color: color,
          minHeight: 12,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  Widget _buildMetricTable() {
    final bool isEvA = _isCarEV(carA);
    final bool isEvB = _isCarEV(carB);
    final double priceA = (carA?['price'] as num?)?.toDouble() ?? 0.0;
    final double priceB = (carB?['price'] as num?)?.toDouble() ?? 0.0;
    final double consA = (carA?['fuelConsumption'] ?? carA?['fuel_consumption'] as num?)?.toDouble() ?? (isEvA ? 15.0 : 6.0);
    final double consB = (carB?['fuelConsumption'] ?? carB?['fuel_consumption'] as num?)?.toDouble() ?? (isEvB ? 15.0 : 6.0);

    final double loanA = _calculateMonthlyLoan(priceA);
    final double loanB = _calculateMonthlyLoan(priceB);
    final double energyA = _calculateMonthlyEnergy(carA);
    final double energyB = _calculateMonthlyEnergy(carB);

    final num? ccA = carA?['engineCC'] ?? carA?['engine_cc'];
    final num? ccB = carB?['engineCC'] ?? carB?['engine_cc'];
    final num? kwA = carA?['motorPower'] ?? carA?['motor_power'] ?? carA?['power'];
    final num? kwB = carB?['motorPower'] ?? carB?['motor_power'] ?? carB?['power'];

    final double taxA = _calculateRoadTax(ccA, isEvA, kwA);
    final double taxB = _calculateRoadTax(ccB, isEvB, kwB);

    final double costPer100A = isEvA ? (consA * 0.57) : (consA * _getEnergyRate(carA));
    final double costPer100B = isEvB ? (consB * 0.57) : (consB * _getEnergyRate(carB));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          _buildTableRow('Starting Price', _formatCurrency(priceA), _formatCurrency(priceB), aWins: priceA < priceB, bWins: priceB < priceA),
          _buildTableRow('Monthly Loan*', 'RM ${loanA.toStringAsFixed(0)}', 'RM ${loanB.toStringAsFixed(0)}', aWins: loanA < loanB, bWins: loanB < loanA),
          _buildTableRow('Monthly Energy', 'RM ${energyA.toStringAsFixed(0)}', 'RM ${energyB.toStringAsFixed(0)}', aWins: energyA < energyB, bWins: energyB < energyA),
          _buildTableRow('Road Tax / yr', 'RM ${taxA.toStringAsFixed(0)}', 'RM ${taxB.toStringAsFixed(0)}', aWins: taxA < taxB, bWins: taxB < taxA),
          _buildTableRow('Energy Source', isEvA ? 'Electric (EV)' : (carA?['fuelType']?.toString() ?? 'Petrol'), isEvB ? 'Electric (EV)' : (carB?['fuelType']?.toString() ?? 'Petrol')),
          _buildTableRow(
            'Engine / Motor',
            isEvA ? (kwA != null && kwA > 0 ? '${kwA.toInt()} kW Motor' : 'Electric Drive') : (ccA != null && ccA > 0 ? '$ccA cc' : 'N/A'),
            isEvB ? (kwB != null && kwB > 0 ? '${kwB.toInt()} kW Motor' : 'Electric Drive') : (ccB != null && ccB > 0 ? '$ccB cc' : 'N/A'),
          ),
          _buildTableRow(
            'Consumption',
            '${consA.toStringAsFixed(1)} ${isEvA ? "kWh/100km" : "L/100km"}',
            '${consB.toStringAsFixed(1)} ${isEvB ? "kWh/100km" : "L/100km"}',
            aWins: costPer100A < costPer100B,
            bWins: costPer100B < costPer100A,
          ),
          _buildTableRow(
            'Cost per 100km',
            'RM ${costPer100A.toStringAsFixed(2)}',
            'RM ${costPer100B.toStringAsFixed(2)}',
            aWins: costPer100A < costPer100B,
            bWins: costPer100B < costPer100A,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Row(
        children: [
          const Expanded(child: Text('Metric', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(carA?['model'] ?? 'Car A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text(carB?['model'] ?? 'Car B', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(String metric, String valA, String valB, {bool? aWins, bool? bWins}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          Expanded(child: Text(metric, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    valA,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: aWins == true ? AppColors.accentGreen : AppColors.textPrimary,
                      fontWeight: aWins == true ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (aWins == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check, color: AppColors.accentGreen, size: 14)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    valB,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: bWins == true ? AppColors.accentGreen : AppColors.textPrimary,
                      fontWeight: bWins == true ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (bWins == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check, color: AppColors.accentGreen, size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('AI SUMMARY', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade100)),
            child: _isAiLoading 
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
              : MarkdownBody(
                  data: _aiSummary,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    listBullet: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                  ),
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => DecisionSummaryScreen(cars: [carA!, carB!])));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              child: const Text('View Decision Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
