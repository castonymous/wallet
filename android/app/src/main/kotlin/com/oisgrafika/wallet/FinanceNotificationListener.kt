package com.oisgrafika.wallet

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class FinanceNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val body = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
        val combined = "$title $body".lowercase()
        if (!combined.contains("rp") && !Regex("\\d{4,}").containsMatchIn(combined)) return
        val keywords = listOf("transaksi", "debit", "kredit", "pembayaran", "transfer", "berhasil", "bayar", "saldo", "received", "diterima", "masuk", "keluar", "refund")
        if (keywords.none { combined.contains(it) }) return
        addDraft(applicationContext, hashMapOf(
            "id" to UUID.randomUUID().toString(),
            "package" to sbn.packageName,
            "title" to title,
            "body" to body,
            "time" to sbn.postTime
        ))
    }

    companion object {
        private const val PREFS = "finance_notification_drafts"
        private const val KEY = "drafts"
        private const val MAX = 80

        private fun load(context: Context): JSONArray {
            return try { JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]") ?: "[]") } catch (_: Exception) { JSONArray() }
        }

        private fun save(context: Context, arr: JSONArray) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, arr.toString()).apply()
        }

        private fun addDraft(context: Context, value: HashMap<String, Any>) {
            val old = load(context)
            val fresh = JSONArray()
            val json = JSONObject()
            value.forEach { (key, item) -> json.put(key, item) }
            fresh.put(json)
            for (i in 0 until minOf(old.length(), MAX - 1)) fresh.put(old.getJSONObject(i))
            save(context, fresh)
        }

        fun readDrafts(context: Context): List<HashMap<String, Any>> {
            val arr = load(context)
            val list = arrayListOf<HashMap<String, Any>>()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                list.add(hashMapOf(
                    "id" to o.optString("id"), "package" to o.optString("package"),
                    "title" to o.optString("title"), "body" to o.optString("body"),
                    "time" to o.optLong("time")
                ))
            }
            return list
        }

        fun removeDraft(context: Context, id: String) {
            val old = load(context); val fresh = JSONArray()
            for (i in 0 until old.length()) { val o = old.optJSONObject(i) ?: continue; if (o.optString("id") != id) fresh.put(o) }
            save(context, fresh)
        }
    }
}
