import 'package:material_ui/material_ui.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/members/system_member.dart';

/// Validated values for creating a PIN-protected member.
class MemberDraft {
  const MemberDraft({required this.name, required this.pin});

  final String name;
  final String pin;
}

/// Choice shown to a migrated member that does not have a PIN yet.
enum MissingPinChoice { setNow, later }

/// Collects the display name and mandatory PIN for a new member.
class CreateMemberDialog extends StatefulWidget {
  const CreateMemberDialog({super.key});

  @override
  State<CreateMemberDialog> createState() => _CreateMemberDialogState();
}

class _CreateMemberDialogState extends State<CreateMemberDialog> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      MemberPinCodec.isValid(_pin.text) &&
      _pin.text == _confirmation.text;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create member'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('member-name'),
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Choose any name',
            ),
          ),
          const SizedBox(height: 12),
          _PinField(
            fieldKey: const Key('member-pin'),
            controller: _pin,
            label: 'PIN',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PinField(
            fieldKey: const Key('member-pin-confirmation'),
            controller: _confirmation,
            label: 'Confirm PIN',
            onChanged: () => setState(() {}),
            errorText:
                _confirmation.text.isNotEmpty && _pin.text != _confirmation.text
                ? 'PINs do not match'
                : null,
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Use 4–12 digits. The PIN cannot be recovered.'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _valid
            ? () => Navigator.pop(
                context,
                MemberDraft(name: _name.text.trim(), pin: _pin.text),
              )
            : null,
        child: const Text('Create'),
      ),
    ],
  );
}

/// Collects and confirms a new PIN for a migrated member.
class SetMemberPinDialog extends StatefulWidget {
  const SetMemberPinDialog({super.key, required this.member});

  final SystemMember member;

  @override
  State<SetMemberPinDialog> createState() => _SetMemberPinDialogState();
}

class _SetMemberPinDialogState extends State<SetMemberPinDialog> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();

  bool get _valid =>
      MemberPinCodec.isValid(_pin.text) && _pin.text == _confirmation.text;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Protect ${widget.member.name}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinField(
          fieldKey: const Key('setup-member-pin'),
          controller: _pin,
          label: 'New PIN',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _PinField(
          fieldKey: const Key('setup-member-pin-confirmation'),
          controller: _confirmation,
          label: 'Confirm PIN',
          onChanged: () => setState(() {}),
          errorText:
              _confirmation.text.isNotEmpty && _pin.text != _confirmation.text
              ? 'PINs do not match'
              : null,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Use 4–12 digits. The PIN cannot be recovered.'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _valid ? () => Navigator.pop(context, _pin.text) : null,
        child: const Text('Set PIN'),
      ),
    ],
  );
}

/// Verifies a PIN before the caller activates a member identity.
class UnlockMemberDialog extends StatefulWidget {
  const UnlockMemberDialog({
    super.key,
    required this.member,
    required this.verify,
  });

  final SystemMember member;
  final Future<bool> Function(String pin) verify;

  @override
  State<UnlockMemberDialog> createState() => _UnlockMemberDialogState();
}

class _UnlockMemberDialogState extends State<UnlockMemberDialog> {
  final _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_checking || !MemberPinCodec.isValid(_pin.text)) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final accepted = await widget.verify(_pin.text);
    if (!mounted) return;
    if (accepted) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _checking = false;
      _error = 'Incorrect PIN';
      _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Unlock ${widget.member.name}'),
    content: _PinField(
      fieldKey: const Key('unlock-member-pin'),
      controller: _pin,
      label: 'PIN',
      autofocus: true,
      enabled: !_checking,
      errorText: _error,
      onChanged: () => setState(() => _error = null),
      onSubmitted: _unlock,
    ),
    actions: [
      TextButton(
        onPressed: _checking ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _checking ? null : _unlock,
        child: _checking
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Unlock'),
      ),
    ],
  );
}

/// Explains PIN migration without forcing an existing member to decide now.
class MissingMemberPinDialog extends StatelessWidget {
  const MissingMemberPinDialog({super.key, required this.member});

  final SystemMember member;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Protect ${member.name} with a PIN?'),
    content: const Text(
      'This profile was created before PIN protection was available. You can set one now or be reminded the next time you select it.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, MissingPinChoice.later),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, MissingPinChoice.setNow),
        child: const Text('Set PIN'),
      ),
    ],
  );
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.fieldKey,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final String label;
  final VoidCallback onChanged;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    autofocus: autofocus,
    enabled: enabled,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 12,
    onChanged: (_) => onChanged(),
    onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    decoration: InputDecoration(
      labelText: label,
      helperText: '4–12 digits',
      errorText: errorText,
      counterText: '',
    ),
  );
}
