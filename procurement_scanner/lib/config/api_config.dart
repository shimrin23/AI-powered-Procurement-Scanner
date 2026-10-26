/// API Configuration for Gemini
class ApiConfig {
  ApiConfig._();

  /// Gemini API Key passed at build/run time via:
  /// `--dart-define=GEMINI_API_KEY=your_key_here`
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Primary model to use for multimodal document recognition.
  static const String geminiModel = 'gemini-3.5-flash-lite';

  /// Fallback model if primary model is unavailable.
  static const String fallbackModel = 'gemini-3.8-flash';
}
