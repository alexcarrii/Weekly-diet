import 'package:web/web.dart' as web;

/// Cambia la dirección visible sin recargar la página (evita que al recargar
/// se vuelva a abrir la pantalla de "nueva contraseña").
void replaceBrowserUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
