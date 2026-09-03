package com.oisgrafika.wallet

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

object FinanceWidgetUpdater {
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            FinanceBalanceWidget::class.java,
            FinanceQuickWidget::class.java,
            FinanceDueWidget::class.java
        ).forEach { cls ->
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            ids.forEach { id ->
                when (cls) {
                    FinanceBalanceWidget::class.java -> FinanceBalanceWidget.update(context, manager, id)
                    FinanceQuickWidget::class.java -> FinanceQuickWidget.update(context, manager, id)
                    FinanceDueWidget::class.java -> FinanceDueWidget.update(context, manager, id)
                }
            }
        }
    }

    fun launchIntent(context: Context, action: String, request: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("finance_action", action)
        }
        return PendingIntent.getActivity(context, request, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class FinanceBalanceWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { update(context, manager, it) } }
    companion object {
        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val p=context.getSharedPreferences("finance_widget",Context.MODE_PRIVATE); val hidden=p.getBoolean("privacy",false)
            val v=RemoteViews(context.packageName,R.layout.widget_finance_balance)
            v.setTextViewText(R.id.widget_available, if(hidden) "Rp •••••••" else p.getString("available","Rp 0"))
            v.setTextViewText(R.id.widget_networth, if(hidden) "Net worth •••••" else "Net worth ${p.getString("netWorth","Rp 0")}")
            v.setOnClickPendingIntent(R.id.widget_balance_root, FinanceWidgetUpdater.launchIntent(context,"open_finance",11))
            manager.updateAppWidget(id,v)
        }
    }
}

class FinanceQuickWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { update(context, manager, it) } }
    companion object {
        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val v=RemoteViews(context.packageName,R.layout.widget_finance_quick)
            v.setOnClickPendingIntent(R.id.quick_expense,FinanceWidgetUpdater.launchIntent(context,"quick_expense",21))
            v.setOnClickPendingIntent(R.id.quick_income,FinanceWidgetUpdater.launchIntent(context,"quick_income",22))
            v.setOnClickPendingIntent(R.id.quick_transfer,FinanceWidgetUpdater.launchIntent(context,"quick_transfer",23))
            manager.updateAppWidget(id,v)
        }
    }
}

class FinanceDueWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) { ids.forEach { update(context, manager, it) } }
    companion object {
        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val p=context.getSharedPreferences("finance_widget",Context.MODE_PRIVATE)
            val v=RemoteViews(context.packageName,R.layout.widget_finance_due)
            v.setTextViewText(R.id.widget_due_text,p.getString("nextDue","Tidak ada jatuh tempo"))
            v.setOnClickPendingIntent(R.id.widget_due_root,FinanceWidgetUpdater.launchIntent(context,"open_finance",31))
            manager.updateAppWidget(id,v)
        }
    }
}
