package com.example.uangkeluar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.os.Build

class UangkuBalanceWidgetProvider : HomeWidgetProvider() {
  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == "ACTION_TOGGLE_VISIBILITY") {
      val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
      val currentHidden = widgetData.getBoolean("widget_balance_hidden", false)
      widgetData.edit().putBoolean("widget_balance_hidden", !currentHidden).commit()

      val appWidgetManager = AppWidgetManager.getInstance(context)
      val componentName = ComponentName(context, UangkuBalanceWidgetProvider::class.java)
      val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
      onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
    }
  }

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    val data = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.uangku_balance_widget)

      val isHidden = data.getBoolean("widget_balance_hidden", false)
      val totalIncomeText =
        data.getString("widget_total_income_text", "Rp 0") ?: "Rp 0"
      val totalExpenseText =
        data.getString("widget_total_expense_text", "Rp 0") ?: "Rp 0"
      val balanceText = data.getString("widget_balance_text", "Rp 0") ?: "Rp 0"
      val netText = data.getString("widget_net_text", balanceText) ?: balanceText
      val isNetNegative = data.getBoolean("widget_net_negative", false)
      val lastUpdatedText = data.getString("widget_last_updated", "Belum diperbarui") ?: "Belum diperbarui"
      val masked = "Rp ••••••"
      val displayBalance = if (isHidden) masked else balanceText
      val displayIncome = if (isHidden) masked else totalIncomeText
      val displayExpense = if (isHidden) masked else totalExpenseText
      val displayNet = if (isHidden) masked else netText
      val visibilityButtonText = if (isHidden) "Show" else "Hide"
      val visibilityIconRes =
        if (isHidden) R.drawable.ic_widget_visibility else R.drawable.ic_widget_visibility_off

      // Styling logic for Dark Mode
      val isDarkMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
      val labelColor = if (isDarkMode) Color.WHITE else Color.parseColor("#FF2D2D2D")
      val valueColor = if (isDarkMode) Color.WHITE else Color.parseColor("#FF111111")
      val expenseColor = Color.parseColor("#FFC24545")

      if (isDarkMode) {
        views.setInt(R.id.widget_root, "setBackgroundColor", Color.BLACK)
        views.setInt(R.id.widget_toggle_visibility_button, "setBackgroundColor", Color.BLACK)
        views.setInt(R.id.widget_income_button, "setBackgroundColor", Color.BLACK)
        views.setInt(R.id.widget_expense_button, "setBackgroundColor", Color.BLACK)
        views.setInt(R.id.widget_income_icon, "setColorFilter", Color.WHITE)
        views.setInt(R.id.widget_expense_icon, "setColorFilter", Color.WHITE)
      } else {
        // Reset or set to default colors in light mode
        views.setInt(R.id.widget_income_icon, "setColorFilter", Color.parseColor("#FF111111"))
        views.setInt(R.id.widget_expense_icon, "setColorFilter", expenseColor)
      }

      views.setTextColor(R.id.widget_wallet_label, labelColor)
      views.setTextColor(R.id.widget_title, labelColor)
      views.setTextColor(R.id.widget_income_label, labelColor)
      // "kecuali label total pengeluaran" -> use expense color or keep it distinct
      views.setTextColor(R.id.widget_expense_label, if (isDarkMode) Color.parseColor("#FFFF9D8E") else Color.parseColor("#FF2D2D2D"))
      views.setTextColor(R.id.widget_net_label, labelColor)
      views.setTextColor(R.id.widget_last_updated, if (isDarkMode) Color.parseColor("#80FFFFFF") else Color.parseColor("#802D2D2D"))
      views.setTextColor(R.id.widget_income_value, valueColor)
      views.setTextColor(R.id.widget_income_button_text, valueColor)
      views.setTextColor(R.id.widget_toggle_visibility_button, valueColor)

      views.setTextViewText(R.id.widget_balance_value, displayBalance)
      views.setTextViewText(R.id.widget_income_value, displayIncome)
      views.setTextViewText(R.id.widget_expense_value, displayExpense)
      views.setTextViewText(R.id.widget_net_value, displayNet)
      views.setTextViewText(R.id.widget_last_updated, lastUpdatedText)
      views.setTextViewText(R.id.widget_toggle_visibility_button, visibilityButtonText)
      views.setTextViewCompoundDrawablesRelative(
        R.id.widget_toggle_visibility_button,
        visibilityIconRes,
        0,
        0,
        0,
      )

      views.setTextColor(
        R.id.widget_balance_value,
        if (isHidden) {
          valueColor
        } else if (isNetNegative) {
          expenseColor
        } else {
          valueColor
        },
      )
      views.setTextColor(
        R.id.widget_expense_value,
        if (isHidden) valueColor else expenseColor,
      )
      views.setTextColor(
        R.id.widget_net_value,
        if (isHidden) {
          valueColor
        } else if (isNetNegative) {
          expenseColor
        } else {
          valueColor
        },
      )
      views.setTextColor(R.id.widget_expense_button_text, if (isDarkMode) Color.WHITE else expenseColor)

      val expenseLaunchUri =
        data.getString("widget_expense_launch_uri", "uangku://open-expense-input")
      val incomeLaunchUri =
        data.getString("widget_income_launch_uri", "uangku://open-income-input")
      val rootLaunchUri = "uangku://dashboard"
      
      val expensePendingIntent =
        HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse(expenseLaunchUri),
        )
      val incomePendingIntent =
        HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse(incomeLaunchUri),
        )
      val rootPendingIntent =
        HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse(rootLaunchUri),
        )

      // Toggle Visibility Intent (Broadcast instead of Activity)
      val toggleIntent = Intent(context, UangkuBalanceWidgetProvider::class.java).apply {
        action = "ACTION_TOGGLE_VISIBILITY"
      }
      val toggleVisibilityPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        toggleIntent,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
      )

      views.setOnClickPendingIntent(R.id.widget_expense_button, expensePendingIntent)
      views.setOnClickPendingIntent(R.id.widget_income_button, incomePendingIntent)
      views.setOnClickPendingIntent(
        R.id.widget_toggle_visibility_button,
        toggleVisibilityPendingIntent,
      )
      views.setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
