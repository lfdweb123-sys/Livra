import 'api/api_client.dart';

class AppContentConfig {
  final bool bannersEnabled;
  final List<String> banners;
  final bool onboardingEnabled;
  final List<String?> onboardingSlides;
  final String supportEmail;
  final String supportPhone;
  final String supportWhatsapp;

  AppContentConfig({
    required this.bannersEnabled,
    required this.banners,
    required this.onboardingEnabled,
    required this.onboardingSlides,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportWhatsapp,
  });

  factory AppContentConfig.fromMap(Map<String, dynamic> map) => AppContentConfig(
        bannersEnabled: map['bannersEnabled'] ?? true,
        banners: List<String>.from(map['banners'] ?? []),
        onboardingEnabled: map['onboardingEnabled'] ?? true,
        onboardingSlides: List<String?>.from(map['onboardingSlides'] ?? []),
        supportEmail: map['supportEmail'] ?? 'support@livra.app',
        supportPhone: map['supportPhone'] ?? '',
        supportWhatsapp: map['supportWhatsapp'] ?? '',
      );

  static AppContentConfig fallback() => AppContentConfig(
        bannersEnabled: true,
        banners: [],
        onboardingEnabled: true,
        onboardingSlides: [],
        supportEmail: 'support@livra.app',
        supportPhone: '',
        supportWhatsapp: '',
      );
}

/// Appel public (pas besoin d'être connecté — utilisé dès l'onboarding).
class AppContentService {
  Future<AppContentConfig> fetch() async {
    try {
      final res = await ApiClient.instance.get('/api/app-content');
      return AppContentConfig.fromMap(res);
    } catch (_) {
      return AppContentConfig.fallback();
    }
  }
}
