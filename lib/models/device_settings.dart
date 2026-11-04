import 'package:flutter/services.dart';

/// Helper to request exemptions from OS power management and OEM-specific battery killers.
/// Directly matches the Transistorsoft DeviceSettings API.
class DeviceSettings {
  static const MethodChannel _channel =
      MethodChannel('com.custom.bglocation/methods');

  /// Displays the system dialog requesting to ignore battery optimizations (Doze mode exemption).
  ///
  /// On Android 6.0+, triggers `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  /// On iOS, returns `true` (unrestricted by default when background modes are active).
  static Future<bool> showIgnoreBatteryOptimizations() async {
    final result = await _channel.invokeMethod<bool>('requestBatteryExemption');
    return result ?? false;
  }

  /// Opens the OEM-specific Power Manager / AutoStart management screen.
  ///
  /// Intelligently resolves and launches native system activities across:
  /// - **Xiaomi / Redmi / POCO**: MIUI / HyperOS SecurityCenter AutoStart & Powerkeeper
  /// - **Samsung**: Smart Manager / Device Care Battery optimization
  /// - **Huawei**: SystemManager Protected Apps / App Launch management
  /// - **Oppo / Realme**: ColorOS Startup Manager / SafeCenter
  /// - **Vivo**: iManager High Background Power Consumption whitelist
  /// - **Stock / Other**: Standard battery optimization settings
  static Future<bool> showPowerManager() async {
    final result = await _channel.invokeMethod<bool>('showPowerManager');
    return result ?? false;
  }

  /// Checks whether battery optimization is currently ignored (unrestricted) for this app.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? true;
  }

  /// Opens the system application details / permissions settings screen.
  static Future<bool> show() async {
    final result = await _channel.invokeMethod<bool>('openAppSettings');
    return result ?? false;
  }
}
