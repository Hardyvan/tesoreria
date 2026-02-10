import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfiguracionDB {
  static String get host => dotenv.env['DB_HOST'] ?? 'dsi.net.pe';
  static int get puerto => int.tryParse(dotenv.env['DB_PORT'] ?? '3306') ?? 3306;
  static String get usuario => dotenv.env['DB_USER'] ?? '';
  static String get password => dotenv.env['DB_PASS'] ?? '';
  static String get nombreBaseDatos => dotenv.env['DB_NAME'] ?? ''; 
}
