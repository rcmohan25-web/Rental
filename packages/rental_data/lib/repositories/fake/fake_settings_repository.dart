import '../../models/models.dart';
import '../settings_repository.dart';

/// In-memory settings (placeholder numbers, see AppSettings.fakeDefaults).
/// Change [settings] in a test to try other rates.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.settings = AppSettings.fakeDefaults,
    this.latency = Duration.zero,
  });

  AppSettings settings;
  final Duration latency;

  @override
  Future<AppSettings> getSettings() async {
    await Future<void>.delayed(latency);
    return settings;
  }
}
