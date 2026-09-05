import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/data_service.dart';

class OwnershipCalculators extends StatefulWidget {
  final double? initialPrice;
  final Map<String, dynamic>? car;

  const OwnershipCalculators({super.key, this.initialPrice, this.car});

  @override
  State<OwnershipCalculators> createState() => _OwnershipCalculatorsState();
}

class _OwnershipCalculatorsState extends State<OwnershipCalculators> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dataService = DataService();

  final _loanFormKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _downpaymentController = TextEditingController();
  final _interestController = TextEditingController();
  final _tenureController = TextEditingController();
  double _monthlyInstalment = 0;

  final _roadTaxFormKey = GlobalKey<FormState>();
  final _ccController = TextEditingController();
  final _powerController = TextEditingController();
  String _fuelType = 'Petrol/Diesel';
  String _region = 'Peninsular Malaysia';
  String _ownership = 'Private';
  String _bodyType = 'Saloon';
  double _roadTax = 0;

  final _fuelFormKey = GlobalKey<FormState>();
  final _dailyDistanceController = TextEditingController();
  final _daysController = TextEditingController();
  final _consumptionController = TextEditingController();
  final _tankCapacityController = TextEditingController();
  String _selectedFuelType = 'RON95 (Floating)';
  Map<String, double> _liveFuelPrices = {
    'RON95 (Floating)': 2.05,
    'RON97': 3.47,
    'Diesel (Peninsular)': 3.35,
    'RON95 (BUDI 95)': 1.99,
  };
  double _monthlyFuelCost = 0;
  double _annualFuelCost = 0;
  double _costPerKm = 0;
  double _fullTankCost = 0;
  double _fullTankRange = 0;
  double _monthlyKm = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final car = widget.car;
    double? price = widget.initialPrice;

    if (car != null) {
      if (car['price'] != null) {
        price = (car['price'] as num).toDouble();
      }
      if (car['fuelConsumption'] != null) {
        _consumptionController.text = (car['fuelConsumption'] as num).toStringAsFixed(1);
      }
      if (car['isEV'] == true) {
        _fuelType = 'EV';
        if (car['motorPower'] != null) {
          _powerController.text = car['motorPower'].toString();
        } else if (car['power'] != null) {
          _powerController.text = car['power'].toString();
        }
      } else {
        if (car['engineCC'] != null && (car['engineCC'] as num) > 0) {
          _ccController.text = car['engineCC'].toString();
        }
        if (car['fuelType'] != null && car['fuelType'].toString().toLowerCase().contains('diesel')) {
          _selectedFuelType = 'Diesel (Peninsular)';
        }
      }
      if (car['bodyType'] != null) {
        final bt = car['bodyType'].toString().toLowerCase();
        if (bt.contains('sedan') || bt.contains('saloon')) {
          _bodyType = 'Saloon';
        } else {
          _bodyType = 'Non-Saloon';
        }
      }
    }

    if (price != null) {
      _priceController.text = price.toStringAsFixed(0);
      _downpaymentController.text = (price * 0.1).toStringAsFixed(0);
    }
    _interestController.text = '3.0';
    _tenureController.text = '7';

    _dailyDistanceController.text = '40';
    _daysController.text = '22';
    if (_consumptionController.text.isEmpty) {
      _consumptionController.text = '6.0';
    }
    _tankCapacityController.text = '40';

    _loadFuelPrices();

    if (car != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateLoan();
        _calculateRoadTax();
        _calculateFuelCost();
      });
    }
  }

  Future<void> _loadFuelPrices() async {
    try {
      final results = await Future.wait([
        _dataService.fetchLatestFuelPrices(),
        SharedPreferences.getInstance(),
      ]);
      final prices = results[0] as Map<String, dynamic>;
      final prefs = results[1] as SharedPreferences;
      final savedFuel = prefs.getString('preferred_fuel');

      if (mounted && prices.isNotEmpty) {
        setState(() {
          prices.forEach((key, val) {
            if (val is num) {
              _liveFuelPrices[key] = val.toDouble();
            }
          });
          if (widget.car == null || widget.car!['isEV'] != true) {
            if (savedFuel != null && savedFuel.isNotEmpty && _liveFuelPrices.containsKey(savedFuel)) {
              _selectedFuelType = savedFuel;
            }
          }
          if (_monthlyFuelCost > 0) {
            _calculateFuelCost();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceController.dispose();
    _downpaymentController.dispose();
    _interestController.dispose();
    _tenureController.dispose();
    _ccController.dispose();
    _powerController.dispose();
    _dailyDistanceController.dispose();
    _daysController.dispose();
    _consumptionController.dispose();
    _tankCapacityController.dispose();
    super.dispose();
  }

  void _calculateLoan() {
    if (_loanFormKey.currentState == null || !_loanFormKey.currentState!.validate()) return;

    double price = double.parse(_priceController.text.trim());
    double downpayment = double.tryParse(_downpaymentController.text.trim()) ?? 0;
    double interestRate = double.parse(_interestController.text.trim()) / 100;
    int tenureYears = int.parse(_tenureController.text.trim());

    double principal = price - downpayment;
    double totalInterest = principal * interestRate * tenureYears;
    double totalPayable = principal + totalInterest;
    setState(() {
      _monthlyInstalment = totalPayable / (tenureYears * 12);
    });
  }

  double _calculateEVTax(double kw) {
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
    if (kw <= 200.0) return 195.0;
    if (kw <= 210.0) return 215.0;
    if (kw <= 220.0) return 235.0;
    if (kw <= 230.0) return 255.0;
    if (kw <= 240.0) return 275.0;
    if (kw <= 250.0) return 295.0;
    if (kw <= 260.0) return 320.0;
    if (kw <= 270.0) return 345.0;
    if (kw <= 280.0) return 370.0;
    if (kw <= 290.0) return 395.0;
    if (kw <= 300.0) return 420.0;
    if (kw <= 310.0) return 450.0;
    if (kw <= 410.0) return 450.0 + (kw - 310.0) / 10.0 * 20.0;
    if (kw <= 510.0) return 650.0 + (kw - 410.0) / 10.0 * 20.0;
    if (kw <= 610.0) return 850.0 + (kw - 510.0) / 10.0 * 20.0;
    return 1050.0 + (kw - 610.0) / 10.0 * 20.0;
  }

  void _calculateRoadTax() {
    if (_roadTaxFormKey.currentState == null || !_roadTaxFormKey.currentState!.validate()) return;

    double tax = 0;

    if (_fuelType == 'EV') {
      double kw = double.parse(_powerController.text.trim());
      tax = _calculateEVTax(kw);
    } else {
      int cc = int.parse(_ccController.text.trim());
      bool isCompany = _ownership == 'Company';

      if (_region == 'Peninsular Malaysia') {
        if (_bodyType == 'Saloon') {
          if (isCompany) {
            if (cc <= 1000) tax = 40;
            else if (cc <= 1200) tax = 110;
            else if (cc <= 1400) tax = 140;
            else if (cc <= 1600) tax = 180;
            else if (cc <= 1800) tax = 400 + (cc - 1600) * 0.80;
            else if (cc <= 2000) tax = 560 + (cc - 1800) * 1.00;
            else if (cc <= 2500) tax = 760 + (cc - 2000) * 2.00;
            else if (cc <= 3000) tax = 1760 + (cc - 2500) * 5.00;
            else tax = 4260 + (cc - 3000) * 9.00;
          } else {
            if (cc <= 1000) tax = 20;
            else if (cc <= 1200) tax = 55;
            else if (cc <= 1400) tax = 70;
            else if (cc <= 1600) tax = 90;
            else if (cc <= 1800) tax = 200 + (cc - 1600) * 0.40;
            else if (cc <= 2000) tax = 280 + (cc - 1800) * 0.50;
            else if (cc <= 2500) tax = 380 + (cc - 2000) * 1.00;
            else if (cc <= 3000) tax = 880 + (cc - 2500) * 2.50;
            else tax = 2130 + (cc - 3000) * 4.50;
          }
        } else {
          if (isCompany) {
            if (cc <= 1600) tax = 200;
            else if (cc <= 1800) tax = 250 + (cc - 1600) * 0.50;
            else if (cc <= 2000) tax = 350 + (cc - 1800) * 0.80;
            else if (cc <= 2500) tax = 510 + (cc - 2000) * 1.00;
            else if (cc <= 3000) tax = 1010 + (cc - 2500) * 2.00;
            else tax = 2010 + (cc - 3000) * 2.00;
          } else {
            if (cc <= 1000) tax = 20;
            else if (cc <= 1200) tax = 85;
            else if (cc <= 1400) tax = 100;
            else if (cc <= 1600) tax = 120;
            else if (cc <= 1800) tax = 300 + (cc - 1600) * 0.30;
            else if (cc <= 2000) tax = 360 + (cc - 1800) * 0.40;
            else if (cc <= 2500) tax = 440 + (cc - 2000) * 0.80;
            else if (cc <= 3000) tax = 840 + (cc - 2500) * 1.60;
            else tax = 1640 + (cc - 3000) * 1.60;
          }
        }
      } else if (_region == 'Sabah' || _region == 'Sarawak') {
        if (cc <= 1000) tax = 20;
        else if (cc <= 1200) tax = 24;
        else if (cc <= 1400) tax = 28;
        else if (cc <= 1600) tax = 32;
        else if (cc <= 1800) tax = 60 + (cc - 1600) * 0.10;
        else if (cc <= 2000) tax = 80 + (cc - 1800) * 0.20;
        else if (cc <= 2500) tax = 120 + (cc - 2000) * 0.50;
        else if (cc <= 3000) tax = 370 + (cc - 2500) * 0.50;
        else tax = 620 + (cc - 3000) * 1.00;
      } else {
        tax = 20;
      }
    }

    setState(() {
      _roadTax = tax;
    });
  }

  void _calculateFuelCost() {
    if (_fuelFormKey.currentState == null || !_fuelFormKey.currentState!.validate()) return;

    double dailyKm = double.tryParse(_dailyDistanceController.text.trim()) ?? 0;
    int days = int.tryParse(_daysController.text.trim()) ?? 0;
    double consumption = double.tryParse(_consumptionController.text.trim()) ?? 0;
    double fuelPrice = _liveFuelPrices[_selectedFuelType] ?? 2.05;
    double tankCap = double.tryParse(_tankCapacityController.text.trim()) ?? 0;

    double monthlyKm = dailyKm * days;
    double costPerKm = (consumption / 100) * fuelPrice;
    double monthlyFuel = monthlyKm * costPerKm;
    double annualFuel = monthlyFuel * 12;
    double fullTank = tankCap * fuelPrice;
    double range = consumption > 0 ? (tankCap / consumption) * 100 : 0;

    setState(() {
      _monthlyKm = monthlyKm;
      _costPerKm = costPerKm;
      _monthlyFuelCost = monthlyFuel;
      _annualFuelCost = annualFuel;
      _fullTankCost = fullTank;
      _fullTankRange = range;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cost Calculator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Loan'),
            Tab(text: 'Road Tax'),
            Tab(text: 'Fuel'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.car != null) _buildCarBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoanCalculator(),
                _buildRoadTaxCalculator(),
                _buildFuelCalculator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarBanner() {
    final car = widget.car!;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${car['make']} ${car['model']}',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-filled from car specifications',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loanFormKey,
        child: Column(
          children: [
            _buildValidatedField(
              label: 'Car Price (RM)',
              controller: _priceController,
              hint: 'e.g. 80000',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Car price is required';
                final n = double.tryParse(val.trim());
                if (n == null || n <= 0) return 'Enter a valid price greater than 0';
                return null;
              },
            ),
            _buildValidatedField(
              label: 'Down Payment (RM)',
              controller: _downpaymentController,
              hint: 'e.g. 8000 (leave 0 if none)',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final n = double.tryParse(val.trim());
                if (n == null || n < 0) return 'Enter a valid amount (0 or more)';
                final price = double.tryParse(_priceController.text.trim()) ?? 0;
                if (n >= price) return 'Down payment must be less than car price';
                return null;
              },
            ),
            _buildValidatedField(
              label: 'Interest Rate (%)',
              controller: _interestController,
              hint: 'e.g. 3.0',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Interest rate is required';
                final n = double.tryParse(val.trim());
                if (n == null || n < 0) return 'Enter a valid interest rate (0 or more)';
                if (n > 30) return 'Interest rate seems too high (max 30%)';
                return null;
              },
            ),
            _buildValidatedField(
              label: 'Loan Tenure (Years)',
              controller: _tenureController,
              hint: 'e.g. 7',
              isInteger: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Loan tenure is required';
                final n = int.tryParse(val.trim());
                if (n == null || n <= 0) return 'Enter a valid tenure (1 or more years)';
                if (n > 9) return 'Maximum loan tenure in Malaysia is 9 years';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _calculateLoan,
              child: const Text('Calculate Instalment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (_monthlyInstalment > 0) ...[
              const SizedBox(height: 32),
              _buildResultCard(
                title: 'Estimated Monthly Instalment',
                primaryValue: 'RM ${_monthlyInstalment.toStringAsFixed(2)}',
                subtitle: 'Based on ${_tenureController.text} years loan at ${_interestController.text}% interest',
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRoadTaxCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _roadTaxFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField('Fuel Type', _fuelType, ['Petrol/Diesel', 'EV'],
                (val) => setState(() { _fuelType = val!; _roadTax = 0; })),
            _buildDropdownField('Region', _region,
                ['Peninsular Malaysia', 'Sabah', 'Sarawak', 'Special Regions (Langkawi/Labuan)'],
                (val) => setState(() { _region = val!; _roadTax = 0; })),
            _buildDropdownField('Ownership', _ownership, ['Private', 'Company'],
                (val) => setState(() { _ownership = val!; _roadTax = 0; })),
            _buildDropdownField('Body Type', _bodyType, ['Saloon', 'Non-Saloon'],
                (val) => setState(() { _bodyType = val!; _roadTax = 0; })),
            const SizedBox(height: 8),
            if (_fuelType == 'EV')
              _buildValidatedField(
                label: 'Motor Power (kW)',
                controller: _powerController,
                hint: 'e.g. 150',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Motor power is required';
                  final n = double.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Enter a valid power in kW (greater than 0)';
                  return null;
                },
              )
            else
              _buildValidatedField(
                label: 'Engine Capacity (cc)',
                controller: _ccController,
                hint: 'e.g. 1600',
                isInteger: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Engine capacity is required';
                  final n = int.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Enter a valid engine capacity in cc (greater than 0)';
                  if (n > 10000) return 'Engine capacity seems too high';
                  return null;
                },
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _calculateRoadTax,
              child: const Text('Calculate Road Tax', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (_roadTax > 0) ...[
              const SizedBox(height: 32),
              _buildResultCard(
                title: 'Annual Road Tax',
                primaryValue: 'RM ${_roadTax.toStringAsFixed(2)}',
                subtitle: '$_region • $_ownership • $_bodyType',
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFuelCalculator() {
    final fuelTypes = [
      'RON95 (Floating)',
      'RON97',
      'Diesel (Peninsular)',
      'RON95 (BUDI 95)',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _fuelFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField(
              'Fuel Type & Rate',
              _selectedFuelType,
              fuelTypes,
              (val) {
                if (val != null) {
                  setState(() {
                    _selectedFuelType = val;
                  });
                  if (_monthlyFuelCost > 0) {
                    _calculateFuelCost();
                  }
                }
              },
              displayLabels: {
                for (var f in fuelTypes)
                  f: '$f (RM ${(_liveFuelPrices[f] ?? 2.05).toStringAsFixed(2)}/L)'
              },
            ),
            const SizedBox(height: 4),
            _buildValidatedField(
              label: 'Fuel Economy (L/100km)',
              controller: _consumptionController,
              hint: 'e.g. 6.0',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Fuel economy is required';
                final n = double.tryParse(val.trim());
                if (n == null || n <= 0) return 'Enter a valid consumption (greater than 0)';
                if (n > 40) return 'Consumption seems too high';
                return null;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: _buildValidatedField(
                    label: 'Daily Distance (km)',
                    controller: _dailyDistanceController,
                    hint: 'e.g. 40',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final n = double.tryParse(val.trim());
                      if (n == null || n <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildValidatedField(
                    label: 'Days / Month',
                    controller: _daysController,
                    hint: 'e.g. 22',
                    isInteger: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      final n = int.tryParse(val.trim());
                      if (n == null || n <= 0 || n > 31) return '1 to 31 days';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            _buildValidatedField(
              label: 'Fuel Tank Capacity (L) (Optional)',
              controller: _tankCapacityController,
              hint: 'e.g. 40',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return null;
                final n = double.tryParse(val.trim());
                if (n == null || n <= 0) return 'Enter a valid capacity';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _calculateFuelCost,
              child: const Text('Calculate Fuel Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (_monthlyFuelCost > 0) ...[
              const SizedBox(height: 32),
              _buildFuelResultCard(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String primaryValue,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            primaryValue,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFuelResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimated Monthly Fuel', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            'RM ${_monthlyFuelCost.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on ${_monthlyKm.toStringAsFixed(0)} km / month (${_dailyDistanceController.text} km/day × ${_daysController.text} days)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Cost / km', 'RM ${_costPerKm.toStringAsFixed(2)}'),
              _buildStatItem('Annual Fuel', 'RM ${_annualFuelCost.toStringAsFixed(2)}'),
              if (_fullTankCost > 0)
                _buildStatItem('Full Tank', 'RM ${_fullTankCost.toStringAsFixed(2)}')
              else if (_fullTankRange > 0)
                _buildStatItem('Est. Range', '~${_fullTankRange.toStringAsFixed(0)} km'),
            ],
          ),
          if (_fullTankRange > 0 && _fullTankCost > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_gas_station_outlined, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Full tank (${_tankCapacityController.text}L) provides ~${_fullTankRange.toStringAsFixed(0)} km cruising range.',
                      style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildValidatedField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    String? hint,
    bool isInteger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isInteger
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accentRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accentRed, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          errorStyle: const TextStyle(color: AppColors.accentRed),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    Map<String, String>? displayLabels,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                onChanged: onChanged,
                items: items.map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    displayLabels?[e] ?? e,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
