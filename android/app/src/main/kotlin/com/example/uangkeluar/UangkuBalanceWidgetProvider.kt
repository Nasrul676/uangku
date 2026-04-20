package com.example.uangkeluar

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class UangkuBalanceWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.uangku_balance_widget)

      val isHidden = widgetData.getBoolean("widget_balance_hidden", false)
      val totalIncomeText =
        widgetData.getString("widget_total_income_text", "Rp 0") ?: "Rp 0"
      val totalExpenseText =
        widgetData.getString("widget_total_expense_text", "Rp 0") ?: "Rp 0"
      val balanceText = widgetData.getString("widget_balance_text", "Rp 0") ?: "Rp 0"
      val netText = widgetData.getString("widget_net_text", balanceText) ?: balanceText
      val isNetNegative = widgetData.getBoolean("widget_net_negative", false)
      val masked = "Rp ••••••"
      val displayBalance = if (isHidden) masked else balanceText
      val displayIncome = if (isHidden) masked else totalIncomeText
      val displayExpense = if (isHidden) masked else totalExpenseText
      val displayNet = if (isHidden) masked else netText
      val visibilityButtonText = if (isHidden) "Show" else "Hide"
      val visibilityIconRes =
        if (isHidden) R.drawable.ic_widget_visibility else R.drawable.ic_widget_visibility_off
      views.setTextViewText(R.id.widget_balance_value, displayBalance)
      views.setTextViewText(R.id.widget_income_value, displayIncome)
      views.setTextViewText(R.id.widget_expense_value, displayExpense)
      views.setTextViewText(R.id.widget_net_value, displayNet)
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
          Color.parseColor("#FF111111")
        } else if (isNetNegative) {
          Color.parseColor("#FFC24545")
        } else {
          Color.parseColor("#FF111111")
        },
      )
      views.setTextColor(
        R.id.widget_expense_value,
        if (isHidden) Color.parseColor("#FF111111") else Color.parseColor("#FFC24545"),
      )
      views.setTextColor(
        R.id.widget_net_value,
        if (isHidden) {
          Color.parseColor("#FF111111")
        } else if (isNetNegative) {
          Color.parseColor("#FFC24545")
        } else {
          Color.parseColor("#FF111111")
        },
      )

      val expenseLaunchUri =
        widgetData.getString("widget_expense_launch_uri", "uangku://open-expense-input")
      val incomeLaunchUri =
        widgetData.getString("widget_income_launch_uri", "uangku://open-income-input")
      val toggleVisibilityLaunchUri =
        widgetData.getString(
          "widget_toggle_visibility_launch_uri",
          "uangku://toggle-balance-visibility",
        )
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
      val toggleVisibilityPendingIntent =
        HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse(toggleVisibilityLaunchUri),
        )

      views.setOnClickPendingIntent(R.id.widget_expense_button, expensePendingIntent)
      views.setOnClickPendingIntent(R.id.widget_income_button, incomePendingIntent)
      views.setOnClickPendingIntent(
        R.id.widget_toggle_visibility_button,
        toggleVisibilityPendingIntent,
      )
      views.setOnClickPendingIntent(R.id.widget_root, expensePendingIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
