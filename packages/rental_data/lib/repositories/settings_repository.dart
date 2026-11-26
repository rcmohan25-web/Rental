import '../models/models.dart';

/// Reads the admin-edited settings (commission, deposit rate, late fee...).
abstract class SettingsRepository {
  Future<AppSettings> getSettings();
}
