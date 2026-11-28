package com.example.note_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Tether can display decrypted private content at any point. Enforce
        // capture protection at the native window boundary so screenshots,
        // screen recording, and Android's recents snapshot cannot bypass the
        // Flutter authorization layer.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
