import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android prevents protected content capture and OS backup', () {
    final activity = File(
      'android/app/src/main/kotlin/com/example/note_app/MainActivity.kt',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    expect(manifest, contains('android:allowBackup="false"'));
  });
}
