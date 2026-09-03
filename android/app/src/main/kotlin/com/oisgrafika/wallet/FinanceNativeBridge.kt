package com.oisgrafika.wallet

import android.app.Activity
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

object FinanceNativeBridge {
    private const val CHANNEL = "com.oisgrafika.wallet/finance"

    fun setup(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgets" -> {
                    val prefs = activity.getSharedPreferences("finance_widget", Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString("available", call.argument<String>("available") ?: "Rp 0")
                        .putString("liabilities", call.argument<String>("liabilities") ?: "Rp 0")
                        .putString("receivables", call.argument<String>("receivables") ?: "Rp 0")
                        .putString("netWorth", call.argument<String>("netWorth") ?: "Rp 0")
                        .putString("nextDue", call.argument<String>("nextDue") ?: "Tidak ada jatuh tempo")
                        .apply()
                    FinanceWidgetUpdater.updateAll(activity)
                    result.success(true)
                }
                "setWidgetPrivacy" -> {
                    val hidden = call.argument<Boolean>("hidden") ?: false
                    activity.getSharedPreferences("finance_widget", Context.MODE_PRIVATE).edit().putBoolean("privacy", hidden).apply()
                    FinanceWidgetUpdater.updateAll(activity)
                    result.success(true)
                }
                "getWidgetPrivacy" -> {
                    result.success(activity.getSharedPreferences("finance_widget", Context.MODE_PRIVATE).getBoolean("privacy", false))
                }
                "consumeLaunchAction" -> {
                    val action = activity.intent?.getStringExtra("finance_action")
                    activity.intent?.removeExtra("finance_action")
                    result.success(action)
                }
                "openNotificationAccessSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }
                "isNotificationAccessEnabled" -> {
                    val enabled = Settings.Secure.getString(
                        activity.contentResolver,
                        "enabled_notification_listeners"
                    ).orEmpty()
                    val granted = enabled.split(':').any { flatName ->
                        ComponentName.unflattenFromString(flatName)?.packageName == activity.packageName
                    }
                    result.success(granted)
                }
                "getNotificationDrafts" -> result.success(FinanceNotificationListener.readDrafts(activity))
                "removeNotificationDraft" -> {
                    val id = call.argument<String>("id") ?: ""
                    FinanceNotificationListener.removeDraft(activity, id)
                    result.success(true)
                }
                "ocrImage" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success("")
                    } else {
                        try {
                            val image = InputImage.fromFilePath(activity, Uri.fromFile(File(path)))
                            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                            recognizer.process(image)
                                .addOnSuccessListener { text -> recognizer.close(); result.success(text.text) }
                                .addOnFailureListener { _ -> recognizer.close(); result.success("") }
                        } catch (_: Exception) { result.success("") }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
