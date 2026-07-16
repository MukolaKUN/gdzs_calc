import 'package:flutter/services.dart';

abstract interface class HapticGateway {
  Future<void> mediumImpact();
  Future<void> heavyImpact();
}

class SystemHapticGateway implements HapticGateway {
  const SystemHapticGateway();

  @override
  Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  @override
  Future<void> heavyImpact() => HapticFeedback.heavyImpact();
}
