import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get cartoApiKey => dotenv.env['CARTO_API_KEY'] ?? '';
  static const String apiHost = 'http://10.0.2.2:3000';
}
