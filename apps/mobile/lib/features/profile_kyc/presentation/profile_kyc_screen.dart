import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';

/// Placeholder, replace with the real screen (Mohan).
class ProfileKycScreen extends StatelessWidget {
  const ProfileKycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile and ID')),
      body: const PlaceholderView(
        title: 'Profile and ID',
        owner: 'Mohan',
        description:
            'Profile edit, ID upload with consent notice, verification status banner, ID gate guard.',
      ),
    );
  }
}
