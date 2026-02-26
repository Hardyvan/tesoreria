import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    var content = file.readAsStringSync();
    var changed = false;
    
    if (content.contains('IndicadorConexion(')) {
      content = content.replaceAll('IndicadorConexion(', 'BannerSinConexion(');
      changed = true;
    }
    if (content.contains('a_tema_app.dart')) {
      content = content.replaceAll('a_tema_app.dart', 'a_tema.dart');
      changed = true;
    }
    if (content.contains('d_manejador_errores.dart')) {
      content = content.replaceAll('../../myPagesTema/d_manejador_errores.dart', 'package:dsi/myPagesTema/c_ui_kit.dart');
      changed = true;
    }
    
    // Also fix prefixText error in b_crear_actividad.dart if it has prefixText
    if (file.path.endsWith('b_crear_actividad.dart') && content.contains('prefixText:')) {
      content = content.replaceAll('prefixText: \'S/ \',', 'prefixIcon: Icons.monetization_on,');
      changed = true;
    }
    
    if (changed) {
      file.writeAsStringSync(content);
      stdout.writeln('Fixed \${file.path}'); // Usamos stdout instead of print for script
    }
  }
}
