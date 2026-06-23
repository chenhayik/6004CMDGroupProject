import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:form_validator/form_validator.dart';

import '../../models/coach_profile.dart';
import '../../services/coach_service.dart';

/// Coach self-registration / edit form. Writes to `coaches/{uid}` — a user may
/// only create or edit their own profile (enforced in firestore.rules).
class CoachRegisterView extends StatefulWidget {
  final CoachProfile? existing;
  const CoachRegisterView({super.key, this.existing});

  @override
  State<CoachRegisterView> createState() => _CoachRegisterViewState();
}

class _CoachRegisterViewState extends State<CoachRegisterView> {
  static const _indigo = Color(0xFF6366F1);
  static const _bg = Color(0xFFF8FAFC);

  final _formKey = GlobalKey<FormState>();
  final _coachService = CoachService();

  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _rate;
  late final TextEditingController _availability;
  late final TextEditingController _bio;
  late final TextEditingController _contact;

  final Set<String> _specs = {};
  ContactMethod _contactMethod = ContactMethod.whatsapp;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.displayName ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _rate = TextEditingController(
        text: e != null && e.hourlyRateMyr > 0 ? '${e.hourlyRateMyr}' : '');
    _availability = TextEditingController(text: e?.availability ?? '');
    _bio = TextEditingController(text: e?.bio ?? '');
    _contact = TextEditingController(text: e?.contactValue ?? '');
    if (e != null) {
      _specs.addAll(e.specializations);
      _contactMethod = e.contactMethod;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _rate.dispose();
    _availability.dispose();
    _bio.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_specs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one specialization.')),
      );
      return;
    }

    setState(() => _saving = true);
    final coach = CoachProfile(
      uid: uid,
      displayName: _name.text.trim(),
      specializations: _specs.toList(),
      hourlyRateMyr: int.tryParse(_rate.text.trim()) ?? 0,
      availability: _availability.text.trim(),
      bio: _bio.text.trim(),
      contactMethod: _contactMethod,
      contactValue: _contact.text.trim(),
      city: _city.text.trim(),
    );

    try {
      await _coachService.upsert(coach);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coach profile saved.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Coach profile save failed: $e');
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Couldn’t save your profile. Please try again.')),
      );
    }
  }

  String get _contactHint {
    switch (_contactMethod) {
      case ContactMethod.whatsapp:
        return 'e.g. 60123456789 (with country code)';
      case ContactMethod.phone:
        return 'e.g. 0123456789';
      case ContactMethod.email:
        return 'e.g. coach@email.com';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: Text(
          isEdit ? 'Edit Coach Profile' : 'Become a Coach',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _label('Display name'),
            _field(
              _name,
              hint: 'Your professional name',
              validator: ValidationBuilder()
                  .minLength(2, 'Enter your name')
                  .maxLength(50)
                  .build(),
            ),
            _label('City'),
            _field(_city, hint: 'e.g. Kuala Lumpur'),
            _label('Hourly rate (MYR)'),
            _field(
              _rate,
              hint: 'e.g. 80',
              prefix: 'RM ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter a valid rate';
                if (n > 100000) return 'That looks too high';
                return null;
              },
            ),
            _label('Specializations'),
            _specChips(),
            _label('Availability'),
            _field(_availability, hint: 'e.g. Weekday evenings, weekends'),
            _label('Short bio'),
            _field(_bio,
                hint: 'Experience, certifications, training style…',
                maxLines: 4),
            const SizedBox(height: 16),
            _label('Contact method'),
            _contactMethodPicker(),
            const SizedBox(height: 12),
            _label('Contact detail'),
            _field(
              _contact,
              hint: _contactHint,
              keyboardType: _contactMethod == ContactMethod.email
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              validator: ValidationBuilder()
                  .minLength(3, 'Enter a contact detail')
                  .build(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save changes' : 'Publish profile',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Form bits ───────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 0, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B))),
      );

  Widget _field(
    TextEditingController controller, {
    String? hint,
    String? prefix,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _indigo),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _specChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CoachSpecializations.all.entries.map((e) {
        final selected = _specs.contains(e.key);
        return GestureDetector(
          onTap: () => setState(() {
            if (!_specs.remove(e.key)) _specs.add(e.key);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _indigo : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: selected ? _indigo : Colors.grey.shade300),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _contactMethodPicker() {
    return Row(
      children: ContactMethod.values.map((m) {
        final selected = _contactMethod == m;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _contactMethod = m),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _indigo.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? _indigo : Colors.grey.shade300),
              ),
              child: Text(
                m.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? _indigo : Colors.black54,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
