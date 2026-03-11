// On web use browser download; on mobile/desktop use path_provider + file + share.
export 'export_handler_io.dart' if (dart.library.html) 'export_handler_web.dart';
