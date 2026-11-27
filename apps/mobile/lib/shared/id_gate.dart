import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_data/rental_data.dart';

import '../features/profile_kyc/application/profile_providers.dart';

/// The ID gate (plan section 4.1). Call it before sending a request, publishing
/// a listing or accepting a request. Returns true when an ID has been
/// submitted (pending or verified). Otherwise it explains why and offers to go
/// to the ID screen, and returns false. The database enforces the same rule
/// (KYC_REQUIRED), this only gives a friendly message first.
Future<bool> ensureIdSubmitted(BuildContext context, WidgetRef ref) async {
  final KycStatus status;
  try {
    status = (await ref.refresh(myProfileProvider.future)).kycStatus;
  } catch (_) {
    // Could not check: let the server decide.
    return true;
  }
  if (status == KycStatus.pending || status == KycStatus.verified) return true;
  if (!context.mounted) return false;

  final rejected = status == KycStatus.rejected;
  final goToId = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(rejected ? 'Send your ID again' : 'Submit your ID first'),
      content: Text(
        rejected
            ? 'Your last ID was not accepted. Please submit it again before '
                'you borrow or lend.'
            : 'Everyone submits an ID before borrowing or renting out an '
                'item. An admin checks it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Submit ID'),
        ),
      ],
    ),
  );
  if (goToId == true && context.mounted) {
    await context.push('/profile/verify-id');
  }
  return false;
}
