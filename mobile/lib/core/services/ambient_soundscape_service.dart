import 'package:flutter/foundation.dart';
import 'app_settings_service.dart';

enum AmbientSoundscapeType {
  none,
  rain,
  library,
}

class AmbientSoundscapeInfo {
  final AmbientSoundscapeType type;
  final String id;
  final String title;
  final String subtitle;
  final String iconGlyph;

  const AmbientSoundscapeInfo({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconGlyph,
  });
}

class AmbientSoundscapeService {
  static final AmbientSoundscapeService _instance = AmbientSoundscapeService._internal();
  factory AmbientSoundscapeService() => _instance;
  AmbientSoundscapeService._internal();

  static const List<AmbientSoundscapeInfo> availableSoundscapes = [
    AmbientSoundscapeInfo(
      type: AmbientSoundscapeType.none,
      id: 'none',
      title: 'Pure Voice',
      subtitle: 'Unfiltered studio recording with zero background ambience',
      iconGlyph: '🎙️',
    ),
    AmbientSoundscapeInfo(
      type: AmbientSoundscapeType.rain,
      id: 'rain',
      title: 'Monastery Rain',
      subtitle: 'Soft rain against cathedral stained glass with quiet warmth',
      iconGlyph: '🌧️',
    ),
    AmbientSoundscapeInfo(
      type: AmbientSoundscapeType.library,
      id: 'library',
      title: 'Ancient Library',
      subtitle: 'Gentle acoustic room presence and faint parchment resonance',
      iconGlyph: '🏛️',
    ),
  ];

  final ValueNotifier<String> activeSoundscapeId = ValueNotifier<String>('none');
  final ValueNotifier<double> soundscapeVolume = ValueNotifier<double>(0.35);

  double get ambientVolume => soundscapeVolume.value;
  String get currentSoundscapeId => activeSoundscapeId.value;

  void initialize() {
    final settings = AppSettingsService();
    activeSoundscapeId.value = settings.ambientSoundscape;
  }

  void setSoundscape(String id) {
    activeSoundscapeId.value = id;
    AppSettingsService().setAmbientSoundscape(id);
    debugPrint('AmbientSoundscapeService: Switched ambient background to $id');
  }

  void setVolume(double volume) {
    soundscapeVolume.value = volume.clamp(0.0, 1.0);
  }

  AmbientSoundscapeInfo get activeSoundscapeInfo {
    return availableSoundscapes.firstWhere(
      (s) => s.id == activeSoundscapeId.value,
      orElse: () => availableSoundscapes.first,
    );
  }
}
