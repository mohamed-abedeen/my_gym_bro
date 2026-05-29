package com.mygymbro.my_gym_bro

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget for MyGymBro.
 *
 * Renders the user's current streak and next training focus. All values
 * are pulled from the shared preferences populated by
 * `WidgetSyncService` on the Dart side (key contract documented there).
 *
 * The widget is intentionally dumb — no business logic, no network, no
 * Drift access. If a key is missing it falls back to a neutral skeleton
 * so the widget never shows the dreaded "Couldn't load" Android string.
 */
class MgbAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Shared prefs written by HomeWidget plugin (matches the keys in
        // lib/core/services/widget_sync_service.dart exactly).
        val prefs = HomeWidgetPlugin.getData(context)

        val streakDays = prefs.getInt("streak_days", 0)
        val streakLabel = prefs.getString("streak_label", null)
            ?: defaultStreakLabel(streakDays)
        val nextFocus = prefs.getString("next_focus", null)?.takeIf { it.isNotBlank() }
        val nextCta = prefs.getString("next_cta", null)?.takeIf { it.isNotBlank() }
            ?: "Tap to open MyGymBro"

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.mgb_widget_layout).apply {
                setTextViewText(R.id.streak_flame, if (streakDays > 0) "🔥" else "💤")
                setTextViewText(R.id.streak_label, streakLabel)
                setTextViewText(
                    R.id.next_focus,
                    if (nextFocus != null) "Train $nextFocus" else "Ready when you are"
                )
                setTextViewText(R.id.next_cta, nextCta)

                // Whole-widget tap → deep-link into the app at /session if a
                // workout is queued, otherwise the home tab. Using HomeWidget's
                // launch intent so the URI flows through the GoRouter shell
                // exactly like a notification deep-link.
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("mygymbro://widget/open")
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun defaultStreakLabel(days: Int): String = when {
        days <= 0 -> "Start a streak"
        days == 1 -> "1-day streak"
        else -> "$days-day streak"
    }
}
