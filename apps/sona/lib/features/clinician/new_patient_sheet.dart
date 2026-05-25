import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/widgets/sona_button.dart';
import 'package:sona/design_system/widgets/sona_date_field.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/clinician/consult_slot_picker.dart';
import 'package:sona/models/intake_template.dart';
import 'package:sona/utils/intake_validation.dart';

typedef RegisterPatientSubmit = Future<void> Function({
  required String childFirstName,
  required String dateOfBirth,
  required String parentName,
  required String parentEmail,
  String? parentPhone,
  required String referralSource,
  String? initialConcerns,
  required bool sendIntakeLink,
  String? templateId,
  String? bookConsultStart,
});

const kReferralSources = <(String value, String label)>[
  ('nhs', 'NHS'),
  ('school', 'School / SENCO'),
  ('gp', 'GP'),
  ('other_parent', 'Another parent'),
  ('self', 'Self-referral'),
  ('other', 'Other'),
];

class NewPatientSheet extends StatefulWidget {
  const NewPatientSheet({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    this.fetchSlots,
  });

  final RegisterPatientSubmit onSubmit;
  final VoidCallback onCancel;
  final Future<List<Map<String, dynamic>>> Function()? fetchSlots;

  static Future<void> show(
    BuildContext context, {
    required RegisterPatientSubmit onSubmit,
    Future<List<Map<String, dynamic>>> Function()? fetchSlots,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: NewPatientSheet(
            onSubmit: onSubmit,
            fetchSlots: fetchSlots,
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: NewPatientSheet(
            onSubmit: onSubmit,
            fetchSlots: fetchSlots,
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  @override
  State<NewPatientSheet> createState() => _NewPatientSheetState();
}

class _NewPatientSheetState extends State<NewPatientSheet> {
  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    if (widget.fetchSlots == null) return;
    setState(() => _slotsLoading = true);
    try {
      final slots = await widget.fetchSlots!();
      if (mounted) setState(() => _slots = slots);
    } finally {
      if (mounted) setState(() => _slotsLoading = false);
    }
  }

  String _childFirstName = '';
  String _dateOfBirth = '';
  String _parentName = '';
  String _parentEmail = '';
  String _parentPhone = '';
  String _referralSource = 'school';
  String _initialConcerns = '';
  bool _sendIntakeLink = true;
  IntakeTemplateId _templateId = IntakeTemplateId.full;
  bool _bookConsult = false;
  String? _selectedSlot;
  List<Map<String, dynamic>> _slots = [];
  bool _slotsLoading = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      if (_childFirstName.trim().isEmpty) _error = 'Child first name is required';
      else if (_dateOfBirth.trim().isEmpty) _error = 'Date of birth is required';
      else if (_parentName.trim().isEmpty) _error = 'Parent name is required';
      else if (!IntakeValidation.isEmail(_parentEmail.trim())) {
        _error = 'Enter a valid parent email';
      }
    });
    if (_error != null) return;

    setState(() => _busy = true);
    try {
      await widget.onSubmit(
        childFirstName: _childFirstName.trim(),
        dateOfBirth: _dateOfBirth.trim(),
        parentName: _parentName.trim(),
        parentEmail: _parentEmail.trim(),
        parentPhone: _parentPhone.trim().isEmpty ? null : _parentPhone.trim(),
        referralSource: _referralSource,
        initialConcerns: _initialConcerns.trim().isEmpty ? null : _initialConcerns.trim(),
        sendIntakeLink: _sendIntakeLink,
        templateId: intakeTemplateIdToApi(_templateId),
        bookConsultStart: _bookConsult ? _selectedSlot : null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SonaColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('New patient', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            SonaTextField(
              label: 'Parent full name',
              value: _parentName,
              onChanged: (v) => setState(() => _parentName = v),
              required: true,
            ),
            const SizedBox(height: 12),
            SonaTextField(
              label: 'Parent email',
              value: _parentEmail,
              onChanged: (v) => setState(() => _parentEmail = v),
              required: true,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            SonaTextField(
              label: 'Parent phone (optional)',
              value: _parentPhone,
              onChanged: (v) => setState(() => _parentPhone = v),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SonaTextField(
              label: 'Child first name',
              value: _childFirstName,
              onChanged: (v) => setState(() => _childFirstName = v),
              required: true,
            ),
            const SizedBox(height: 12),
            SonaDateField(
              label: 'Child date of birth',
              value: _dateOfBirth,
              onChanged: (v) => setState(() => _dateOfBirth = v),
              required: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _referralSource,
              decoration: const InputDecoration(labelText: 'Referral source'),
              items: [
                for (final item in kReferralSources)
                  DropdownMenuItem(value: item.$1, child: Text(item.$2)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _referralSource = v);
              },
            ),
            const SizedBox(height: 12),
            SonaTextField(
              label: 'Initial concerns (optional)',
              value: _initialConcerns,
              onChanged: (v) => setState(() => _initialConcerns = v),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Book consult now'),
              subtitle: const Text('Pin the free 20-minute consult to a slot.'),
              value: _bookConsult,
              onChanged: widget.fetchSlots == null
                  ? null
                  : (v) => setState(() {
                        _bookConsult = v;
                        if (!v) _selectedSlot = null;
                      }),
            ),
            if (_bookConsult) ...[
              ConsultSlotPicker(
                slots: _slots,
                selectedStart: _selectedSlot,
                loading: _slotsLoading,
                onSelected: (s) => setState(() => _selectedSlot = s),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send intake link now'),
              subtitle: const Text('Copy the magic link to share with the parent (no email yet).'),
              value: _sendIntakeLink,
              onChanged: (v) => setState(() => _sendIntakeLink = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: SonaColors.warningText, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SonaButton(
              label: _busy ? 'Registering…' : 'Register patient',
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
