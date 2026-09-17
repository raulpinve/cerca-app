import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get cartoApiKey => dotenv.env['CARTO_API_KEY'] ?? '';
  static const String apiHost = 'https://api.cerca.gestorempresarial.cloud';
  // static const String apiHost = 'http://192.168.10.12:3000';
}
