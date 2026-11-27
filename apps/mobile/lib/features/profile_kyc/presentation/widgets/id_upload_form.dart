import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../../../shared/image_selector.dart';
import '../../../auth/application/auth_error_messages.dart';
import '../../application/profile_providers.dart';

/// ID photo + face photo + consent, then `submit_kyc`. Used by the sign-up ID
/// step and by Profile > Verify identity. Owner: Mohan.
class IdUploadForm extends ConsumerStatefulWidget {
  const IdUploadForm({required this.onSubmitted, super.key});

  /// Called after the ID is submitted successfully.
  final VoidCallback onSubmitted;

  @override
  ConsumerState<IdUploadForm> createState() => _IdUploadFormState();
}

class _IdUploadFormState extends ConsumerState<IdUploadForm> {
  ImageUpload? _id;
  ImageUpload? _face;
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  Future<void> _pick({required bool face}) async {
    setState(() => _error = null);
    final selector = ref.read(imageSelectorProvider);
    final source = face ? PhotoSource.camera : await _askSource();
    if (source == null) return;
    try {
      final photo = await selector.pick(source, frontCamera: face);
      if (photo == null || !mounted) return;
      setState(() => face ? _face = photo : _id = photo);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is AppException ? e.message : friendlyAuthError(e),
      );
    }
  }

  Future<PhotoSource?> _askSource() => showModalBottomSheet<PhotoSource>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
              ),
            ],
          ),
        ),
      );

  Future<void> _submit() async {
    final id = _id;
    final face = _face;
    if (id == null || face == null || !_confirmed || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(kycRepositoryProvider)
          .submitKyc(idPhoto: id, facePhoto: face);
      ref
        ..invalidate(myProfileProvider)
        ..invalidate(myKycStatusProvider);
      if (!mounted) return;
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppException && e.code == 'INVALID_STATE'
            ? 'Your ID is already with an admin.'
            : friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _id != null && _face != null && _confirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Notice(
          icon: Icons.lock_outline,
          text: HonestyTexts.idConsentNotice,
        ),
        const SizedBox(height: 8),
        const _Notice(
          icon: Icons.warning_amber_outlined,
          text: HonestyTexts.idMisuseWarning,
        ),
        const SizedBox(height: 8),
        const _Notice(
          icon: Icons.verified_user_outlined,
          text: HonestyTexts.identityManual,
        ),
        const SizedBox(height: 16),
        _PhotoSlot(
          label: 'Photo of your original ID',
          hint: 'Citizenship, passport or driving licence. All four corners '
              'visible, text readable.',
          photo: _id,
          onTap: () => _pick(face: false),
        ),
        const SizedBox(height: 12),
        _PhotoSlot(
          label: 'Photo of your face',
          hint: 'A selfie taken now, in good light.',
          photo: _face,
          onTap: () => _pick(face: true),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text('This is my own ID and my own face.'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: BrandColors.danger)),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Submit ID',
          loading: _busy,
          onPressed: ready ? _submit : null,
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: BrandColors.navy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: BrandColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.hint,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final String hint;
  final ImageUpload? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: photo == null
                      ? const ColoredBox(
                          color: BrandColors.border,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: BrandColors.textMuted,
                          ),
                        )
                      : Image.memory(photo!.bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      photo == null ? hint : 'Added. Tap to replace.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: BrandColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
