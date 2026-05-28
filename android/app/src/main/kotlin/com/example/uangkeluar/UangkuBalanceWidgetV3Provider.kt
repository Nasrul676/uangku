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

class UangkuBalanceWidgetV3Provider : HomeWidgetProvider() {
  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == "ACTION_TOGGLE_VISIBILITY_V3") {
      val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
      val currentHidden = widgetData.getBoolean("widget_balance_hidden", false)
      widgetData.edit().putBoolean("widget_balance_hidden", !currentHidden).commit()

      val appWidgetManager = AppWidgetManager.getInstance(context)
      val componentName = ComponentName(context, UangkuBalanceWidgetV3Provider::class.java)
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
      val views = RemoteViews(context.packageName, R.layout.uangku_balance_widget_v3)

      val isHidden = data.getBoolean("widget_balance_hidden", false)
      val balanceText = data.getString("widget_balance_text", "Rp 0") ?: "Rp 0"
      val isNetNegative = data.getBoolean("widget_net_negative", false)
      
      val masked = "Rp ••••••"
      val displayBalance = if (isHidden) masked else balanceText
      val visibilityButtonText = if (isHidden) "Show" else "Hide"
      val visibilityIconRes =
        if (isHidden) R.drawable.ic_widget_visibility else R.drawable.ic_widget_visibility_off

      // Styling logic for Dark Mode
      val isDarkMode = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
      val valueColor = if (isDarkMode) Color.WHITE else Color.parseColor("#FF111111")
      val expenseColor = Color.parseColor("#FFC24545")

      if (isDarkMode) {
        views.setInt(R.id.widget_root, "setBackgroundColor", Color.parseColor("#73000000"))
        views.setInt(R.id.widget_toggle_visibility_button, "setBackgroundColor", Color.TRANSPARENT)
      } else {
        // Reset colors in light mode (since RemoteViews can recycle views)
        views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.uangku_widget_background)
        views.setInt(R.id.widget_toggle_visibility_button, "setBackgroundResource", R.drawable.uangku_widget_income_cta_background)
      }

      views.setTextColor(R.id.widget_toggle_visibility_button, valueColor)

      views.setTextViewText(R.id.widget_balance_value, displayBalance)
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

      val rootLaunchUri = "uangku://dashboard"
      
      val rootPendingIntent =
        HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse(rootLaunchUri),
        )

      // Toggle Visibility Intent (Broadcast instead of Activity)
      val toggleIntent = Intent(context, UangkuBalanceWidgetV3Provider::class.java).apply {
        action = "ACTION_TOGGLE_VISIBILITY_V3"
      }
      val toggleVisibilityPendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        toggleIntent,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
      )

      views.setOnClickPendingIntent(
        R.id.widget_toggle_visibility_button,
        toggleVisibilityPendingIntent,
      )
      views.setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
