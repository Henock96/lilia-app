package com.dreesis.lilia.lilia_app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Active le mode edge-to-edge pour Android 15+ (SDK 35)
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
