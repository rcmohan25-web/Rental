import 'package:material_ui/material_ui.dart';

import '../constants/honesty_texts.dart';
import '../theme/brand_colors.dart';

/// Reusable "I have read and accept" checkbox. Used for the borrower terms
/// (before payment) and the renter terms (right after Accept). Owner: Smaran.
///
/// The parent keeps the boolean and sends it to the server as
/// `p_terms_accepted`; the server rejects the step when it is false or the
/// terms version is not the one snapshotted on the booking. The helper line
/// says the tick is a recorded acceptance, not a certified e-signature
/// (HonestyTexts.tickIsAcceptance).
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.label = 'I have read and accept the terms',
    this.onReadTerms,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  /// Opens the terms text. The link is hidden when null.
  final VoidCallback? onReadTerms;

  /// Shown in red under the box, for example "Tick the box to continue."
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: value,
          onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          title: Text(label),
        ),
        if (onReadTerms != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReadTerms,
              child: const Text('Read the terms'),
            ),
          ),
        const Text(
          HonestyTexts.tickIsAcceptance,
          style: TextStyle(fontSize: 12, color: BrandColors.textMuted),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 13, color: BrandColors.danger),
          ),
        ],
      ],
    );
  }
}
