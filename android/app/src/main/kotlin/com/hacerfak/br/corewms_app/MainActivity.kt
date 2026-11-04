package com.hacerfak.br.corewms_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val SCANNER_CHANNEL = "corewms/scanner"
    private val SCAN_ACTION = "com.corewms.scan"

    private var scanReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCANNER_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanReceiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context?, intent: Intent?) {
                            if (intent?.action == SCAN_ACTION) {
                                val barcode = intent.getStringExtra("data") 
                                    ?: intent.getStringExtra("scannerdata")
                                    ?: intent.getStringExtra("barcode_string")
                                    ?: intent.getStringExtra("value")

                                if (!barcode.isNullOrEmpty()) {
                                    events?.success(barcode.trim())
                                }
                            }
                        }
                    }

                    val filter = IntentFilter(SCAN_ACTION)
                    // Tratamento obrigatório para Android 13+ (Movfast Ranger 2)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(scanReceiver, filter, Context.RECEIVER_EXPORTED)
                    } else {
                        registerReceiver(scanReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    scanReceiver?.let {
                        unregisterReceiver(it)
                        scanReceiver = null
                    }
                }
            })
    }
}