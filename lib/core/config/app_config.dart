import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get cartoApiKey => dotenv.env['CARTO_API_KEY'] ?? '';
}
