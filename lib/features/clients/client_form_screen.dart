import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/database_provider.dart';
import '../../theme/theme.dart';

/// Create or edit a client (name, phone, email; optional emergency contact).
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key, this.existing});

  final Client? existing;

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _emergency;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _firstName = TextEditingController(text: c?.firstName ?? '');
    _lastName = TextEditingController(text: c?.lastName ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _emergency = TextEditingController(text: c?.emergencyContact ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _emergency.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = AppDatabaseProvider.of(context);
    try {
      if (_isEdit) {
        await db.updateClient(
          id: widget.existing!.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          email: _email.text,
          emergencyContact: _emergency.text,
        );
      } else {
        await db.insertClient(
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          email: _email.text,
          emergencyContact: _emergency.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit client' : 'New client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PelviSpace.md),
          children: [
            Text('FIRST NAME', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Given name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: PelviSpace.md),
            Text('LAST NAME', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Family name'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: PelviSpace.md),
            Text('PHONE', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SizedBox(height: PelviSpace.md),
            Text('EMAIL', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SizedBox(height: PelviSpace.md),
            Text('EMERGENCY CONTACT', style: text.labelMedium),
            const SizedBox(height: PelviSpace.xs),
            TextFormField(
              controller: _emergency,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
            const SizedBox(height: PelviSpace.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PelviColors.inkInverse,
                      ),
                    )
                  : Text(_isEdit ? 'Save' : 'Add client'),
            ),
          ],
        ),
      ),
    );
  }
}
