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
  
  // Loan Calculator State
  final _priceController = TextEditingController();
  final _downpaymentController = TextEditingController();
  final _interestController = TextEditingController();
  final _tenureController = TextEditingController();
  double _monthlyInstalment = 0;

  // Road Tax Calculator State
  final _ccController = TextEditingController();
  final _powerController = TextEditingController(); // kW for EV
  String _fuelType = 'Petrol/Diesel'; // Petrol/Diesel, EV
  String _region = 'Peninsular Malaysia'; // Peninsular, Sabah, Sarawak, Special Regions
  String _ownership = 'Private'; // Private, Company
  String _bodyType = 'Saloon'; // Saloon, Non-Saloon
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

  void _calculateLoan() {
    double price = double.tryParse(_priceController.text) ?? 0;
    double downpayment = double.tryParse(_downpaymentController.text) ?? 0;
    double interestRate = (double.tryParse(_interestController.text) ?? 0) / 100;
    int tenureYears = int.tryParse(_tenureController.text) ?? 0;

    if (price > 0 && tenureYears > 0) {
      double principal = price - downpayment;
      double totalInterest = principal * interestRate * tenureYears;
      double totalPayable = principal + totalInterest;
      setState(() {
        _monthlyInstalment = totalPayable / (tenureYears * 12);
      });
    }
  }

  double _calculateEVTax(double kw) {
    // Latest 2026 EV Road Tax Rates (Official JPJ)
    // Motor Power (kW) : Rate
    if (kw <= 50.0) return 20.0;
    if (kw <= 60.0) return 30.0;
    if (kw <= 70.0) return 40.0;
    if (kw <= 80.0) return 50.0;
    if (kw <= 90.0) return 60.0;
    if (kw <= 100.0) return 70.0;
    
    // Grouping for higher power
    if (kw <= 110.0) return 80.0;
    if (kw <= 120.0) return 90.0;
    if (kw <= 130.0) return 100.0;
    if (kw <= 140.0) return 110.0;
    if (kw <= 150.0) return 120.0;
    
    // Progressive tiers above 150kW
    if (kw <= 160.0) return 135.0;
    if (kw <= 170.0) return 150.0;
    if (kw <= 180.0) return 165.0;
    if (kw <= 190.0) return 180.0;
    if (kw <= 200.0) return 195.0;
    
    // Tiers continue up to 300kW and above
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
    double tax = 0;

    if (_fuelType == 'EV') {
      double kw = double.tryParse(_powerController.text) ?? 0;
      tax = _calculateEVTax(kw);
    } else {
      int cc = int.tryParse(_ccController.text) ?? 0;
      bool isCompany = _ownership == 'Company';

      if (_region == 'Peninsular Malaysia') {
        if (_bodyType == 'Saloon') {
          if (isCompany) {
            // Peninsular Company Saloon (Official JPJ)
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
            // Peninsular Private Saloon
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
          // Peninsular Non-Saloon
          if (isCompany) {
            // Peninsular Company Non-Saloon (SUV/MPV/Pickup)
            if (cc <= 1600) tax = 200;
            else if (cc <= 1800) tax = 250 + (cc - 1600) * 0.50;
            else if (cc <= 2000) tax = 350 + (cc - 1800) * 0.80;
            else if (cc <= 2500) tax = 510 + (cc - 2000) * 1.00;
            else if (cc <= 3000) tax = 1010 + (cc - 2500) * 2.00;
            else tax = 2010 + (cc - 3000) * 2.00;
          } else {
            // Peninsular Private Non-Saloon
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
      }
else if (_region == 'Sabah' || _region == 'Sarawak') {
        // Sabah & Sarawak rates (much lower)
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
        // Special Regions (Labuan, Langkawi, Pangkor) - Flat RM20 for most private
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
      child: Column(
        children: [
          _buildInputField('Car Price (RM)', _priceController),
          _buildInputField('Down Payment (RM)', _downpaymentController),
          _buildInputField('Interest Rate (%)', _interestController),
          _buildInputField('Loan Tenure (Years)', _tenureController),
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
    );
  }

  Widget _buildRoadTaxCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownField('Fuel Type', _fuelType, ['Petrol/Diesel', 'EV'], (val) => setState(() => _fuelType = val!)),
          _buildDropdownField('Region', _region, ['Peninsular Malaysia', 'Sabah', 'Sarawak', 'Special Regions (Langkawi/Labuan)'], (val) => setState(() => _region = val!)),
          _buildDropdownField('Ownership', _ownership, ['Private', 'Company'], (val) => setState(() => _ownership = val!)),
          _buildDropdownField('Body Type', _bodyType, ['Saloon', 'Non-Saloon'], (val) => setState(() => _bodyType = val!)),
          const SizedBox(height: 16),
          if (_fuelType == 'EV')
            _buildInputField('Motor Power (kW)', _powerController)
          else
            _buildInputField('Engine Capacity (cc)', _ccController),
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
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
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

  Widget _buildInputField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
