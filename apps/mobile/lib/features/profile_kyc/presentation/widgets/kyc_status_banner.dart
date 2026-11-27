import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

/// Shows where the user's ID check stands, with the next step.
class KycStatusBanner extends StatelessWidget {
  const KycStatusBanner({required this.info, this.onAction, super.key});

  final KycStatusInfo info;

  /// Opens the ID screen. Shown for "none" and "rejected" only.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (chip, tone, text, action) = switch (info.status) {
      KycStatus.none => (
          'ID not submitted',
          StatusTone.warning,
          'Submit your ID before you borrow or lend. An admin checks it.',
          'Verify identity',
        ),
      KycStatus.pending => (
          'Waiting for an admin',
          StatusTone.info,
          'Your ID is submitted. You can already send or accept requests, '
              'but payment opens only after an admin has checked your ID.',
          null,
        ),
      KycStatus.verified => (
          'ID checked by an admin',
          StatusTone.success,
          HonestyTexts.identityManual,
          null,
        ),
      KycStatus.rejected => (
          'ID not accepted',
          StatusTone.danger,
          info.reason == null
              ? 'Please submit your ID again.'
              : 'Reason: ${info.reason}',
          'Submit again',
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusChip(label: chip, tone: tone),
            const SizedBox(height: 8),
            Text(text),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 12),
              PrimaryButton(label: action, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
