import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class OwnershipCalculators extends StatefulWidget {
  final double? initialPrice;

  const OwnershipCalculators({super.key, this.initialPrice});

  @override
  State<OwnershipCalculators> createState() => _OwnershipCalculatorsState();
}

class _OwnershipCalculatorsState extends State<OwnershipCalculators> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialPrice != null) {
      _priceController.text = widget.initialPrice!.toStringAsFixed(0);
    }
    _interestController.text = '3.0';
    _tenureController.text = '7';
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
    super.dispose();
  }

  void _calculateLoan() {
    if (!_loanFormKey.currentState!.validate()) return;

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
    if (!_roadTaxFormKey.currentState!.validate()) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calculators', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoanCalculator(),
          _buildRoadTaxCalculator(),
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
              const Text('Estimated Monthly Instalment', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                'RM ${_monthlyInstalment.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
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
              const Text('Annual Road Tax', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                'RM ${_roadTax.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ]
          ],
        ),
      ),
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

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
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
                items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
