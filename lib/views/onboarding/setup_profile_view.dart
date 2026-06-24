import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/setup_profile_viewmodel.dart';
import 'select_goal_view.dart';

class SetupProfileView extends StatelessWidget {
  const SetupProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SetupProfileViewModel(),
      child: const _SetupProfileContent(),
    );
  }
}

class _SetupProfileContent extends StatelessWidget {
  const _SetupProfileContent();

  static final _formKey = GlobalKey<FormState>();

// 1. Reusable Label Wrapper
  Widget _buildLabeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A5568),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

// 2. Reusable Input Decoration
  InputDecoration _sharedDecoration({required String hintText, Widget? suffixIcon}) {
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC2D1C5), width: 1),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black26),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
      enabledBorder: outlineBorder,
      // Use copyWith to easily modify just the color/width for other states
      focusedBorder: outlineBorder.copyWith(borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2)),
      errorBorder: outlineBorder.copyWith(borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: outlineBorder.copyWith(borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }

// 3. Reusable Suffix Divider
  Widget _buildSuffix(String text) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFC2D1C5), width: 1),
        ),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.black54, fontSize: 16)),
      ),
    );
  }

  Widget _buildSexDropdown(SetupProfileViewModel vm) {
    return _buildLabeledField(
      'BIOLOGICAL SEX',
      DropdownButtonFormField<String>(
        initialValue: vm.selectedSex,
        icon: const Icon(Icons.keyboard_arrow_down),
        decoration: _sharedDecoration(hintText: 'Select...'),
        items: vm.sexOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: vm.onSexChanged,
        validator: vm.validateSex,
      ),
    );
  }

  Widget _buildAgeField(SetupProfileViewModel vm) {
    return _buildLabeledField(
      'AGE',
      TextFormField(
        controller: vm.ageController,
        keyboardType: TextInputType.number,
        decoration: _sharedDecoration(hintText: 'e.g. 28', suffixIcon: _buildSuffix('Yrs')),
        validator: vm.validateAge,
      ),
    );
  }

  Widget _buildHeightField(SetupProfileViewModel vm) {
    return _buildLabeledField(
      'HEIGHT',
      TextFormField(
        controller: vm.heightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _sharedDecoration(hintText: 'e.g. 175', suffixIcon: _buildSuffix('cm')),
        validator: vm.validateHeight,
      ),
    );
  }

  Widget _buildWeightField(SetupProfileViewModel vm) {
    return _buildLabeledField(
      'WEIGHT',
      TextFormField(
        controller: vm.weightController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _sharedDecoration(hintText: 'e.g. 72.5', suffixIcon: _buildSuffix('kg')),
        validator: vm.validateWeight,
      ),
    );
  }

  Widget _buildActivityDropdown(SetupProfileViewModel vm) {
    return _buildLabeledField(
      'ACTIVITY LEVEL',
      DropdownButtonFormField<String>(
        initialValue: vm.selectedActivityLevel,
        icon: const Icon(Icons.keyboard_arrow_down),
        decoration: _sharedDecoration(hintText: 'Select...'),
        items: vm.activityOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: vm.onActivityChanged,
        validator: vm.validateActivity,
      ),
    );
  }

  void _onNext(BuildContext context, SetupProfileViewModel vm) {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectGoalView(
            formData: vm.collectFormData(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SetupProfileViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'SETUP PROFILE',
          style: TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _onNext(context, vm),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Next →',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personalize Your\nTargets',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'To accurately calculate your Basal Metabolic Rate and daily energy '
                    'needs, we require a few baseline metrics. This ensures your nutrition '
                    'plan is perfectly calibrated for your goals.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 28),
              _buildAgeField(vm),
              const SizedBox(height: 16),
              _buildSexDropdown(vm),
              const SizedBox(height: 16),
              _buildHeightField(vm),
              const SizedBox(height: 16),
              _buildWeightField(vm),
              const SizedBox(height: 16),
              _buildActivityDropdown(vm),
              const SizedBox(height: 32),

            ],
          ),
        ),
      ),


    );
  }
}