import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Registration, also used to edit business details from Settings.
class RegisterScreen extends StatefulWidget {
  final bool editing;
  const RegisterScreen({super.key, this.editing = false});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _email, _phone, _company;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = AppState.instance.profile;
    _name = TextEditingController(text: p?.businessName ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _company = TextEditingController(text: p?.companyNumber ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _company]) {
      c.dispose();
    }
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  String? _validateEmail(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter your business email';
    if (!_emailRe.hasMatch(t)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'Enter a contact telephone number';
    if (digits.length < 10 || digits.length > 13) return 'Enter a valid telephone number';
    return null;
  }

  String? _validateCompany(String? v) {
    final t = (v ?? '').replaceAll(' ', '').toUpperCase();
    if (t.isEmpty) return null; // optional
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(t)) {
      return 'UK company numbers have 8 characters, e.g. 01234567 or SC123456';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await AppState.instance.saveProfile(BusinessProfile(
      businessName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      companyNumber: _company.text.replaceAll(' ', '').toUpperCase(),
    ));
    if (!mounted) return;
    if (widget.editing) {
      showSnack(context, 'Business details saved');
      Navigator.pop(context);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing ? 'Business details' : '')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (!widget.editing) ...[
                const StepHeader(
                  step: 1,
                  of: 4,
                  title: 'Register your business',
                  subtitle: 'These details appear on your temperature logs. '
                      'Logs are emailed to the address you enter here.',
                ),
                const SizedBox(height: 24),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: const InputDecoration(
                    labelText: 'Business name', prefixIcon: Icon(Icons.storefront_rounded), counterText: ''),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your business name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                    labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))],
                decoration: const InputDecoration(
                    labelText: 'Telephone number', prefixIcon: Icon(Icons.phone_rounded)),
                validator: _validatePhone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _company,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Company registration number (optional)',
                  prefixIcon: Icon(Icons.badge_rounded),
                  counterText: '',
                ),
                validator: _validateCompany,
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              const InfoBanner(
                icon: Icons.lock_rounded,
                text: 'Your details and records are stored on this phone only. '
                    'We do not collect or share them.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.editing ? 'Save changes' : 'Continue'),
              ),
              if (!widget.editing) ...[
                const SizedBox(height: 12),
                const Text(
                  'By continuing you agree to the ChillProof terms and privacy policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.muted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
