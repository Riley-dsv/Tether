import 'dart:io';

import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

mobile.DatabaseFactory defaultDatabaseFactory() {
  if (Platform.isLinux || Platform.isWindows) {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }
  return mobile.databaseFactory;
}
