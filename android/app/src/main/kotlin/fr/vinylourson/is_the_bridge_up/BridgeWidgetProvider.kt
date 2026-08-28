package fr.vinylourson.is_the_bridge_up

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget listing the next bridge closures.
 *
 * Deliberately dumb: every string it shows is written by the Flutter side,
 * already formatted and already translated. Formatting dates here would mean
 * a second implementation of the app's l10n and relative-day rules in Kotlin,
 * free to drift from the one that is tested.
 */
class BridgeWidgetProvider : HomeWidgetProvider() {

    companion object {
        /** Rows declared in the layout. The cap is the layout's, not a rule. */
        const val MAX_ROWS = 10

        private const val PREFS = "BridgeWidgetPrefs"
        private const val KEY_ROWS = "rows_"
        private const val DEFAULT_ROWS = 5

        fun saveRowCount(context: Context, widgetId: Int, rows: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putInt(KEY_ROWS + widgetId, rows)
                .apply()
        }

        fun loadRowCount(context: Context, widgetId: Int): Int =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_ROWS + widgetId, DEFAULT_ROWS)

        fun clearRowCount(context: Context, widgetId: Int) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_ROWS + widgetId)
                .apply()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            render(context, appWidgetManager, widgetId, widgetData)
        }
    }

    /** Resizing has to re-render: the height decides how many rows can fit. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(
            context,
            appWidgetManager,
            appWidgetId,
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE),
        )
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (widgetId in appWidgetIds) clearRowCount(context, widgetId)
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_bridge)

        views.setTextViewText(R.id.widget_status, data.getString("bridge.status", "") ?: "")
        views.setTextViewText(R.id.widget_updated, data.getString("bridge.updated", "") ?: "")

        // The user's choice, capped by what the widget is currently tall
        // enough to show. Asking for ten rows in a two-row-high widget would
        // silently clip them, which reads as missing data rather than a
        // too-small widget.
        val wanted = loadRowCount(context, widgetId)
        val fits = rowsThatFit(appWidgetManager, widgetId)
        val available = data.getInt("bridge.count", 0)
        val shown = minOf(wanted, fits, available, MAX_ROWS)

        for (i in 0 until MAX_ROWS) {
            val rowId = rowIds[i]
            if (i < shown) {
                views.setViewVisibility(rowId, android.view.View.VISIBLE)
                views.setTextViewText(
                    whenIds[i],
                    data.getString("bridge.row$i.when", "") ?: "",
                )
                views.setTextViewText(
                    whatIds[i],
                    data.getString("bridge.row$i.what", "") ?: "",
                )
            } else {
                views.setViewVisibility(rowId, android.view.View.GONE)
            }
        }

        // Only shown when there is genuinely nothing to list, not when the
        // widget is merely too short for the rows it has.
        views.setViewVisibility(
            R.id.widget_empty,
            if (available == 0) android.view.View.VISIBLE else android.view.View.GONE,
        )
        views.setTextViewText(R.id.widget_empty, data.getString("bridge.empty", "") ?: "")

        val open = Intent(context, MainActivity::class.java)
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(
                context,
                widgetId,
                open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /** How many rows the widget's current height leaves room for. */
    private fun rowsThatFit(manager: AppWidgetManager, widgetId: Int): Int {
        val options = manager.getAppWidgetOptions(widgetId)
        val minHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (minHeightDp <= 0) return MAX_ROWS      // unknown: trust the user's choice
        val forRows = minHeightDp - HEADER_DP
        return (forRows / ROW_DP).coerceIn(1, MAX_ROWS)
    }
}

private const val HEADER_DP = 44
private const val ROW_DP = 26

private val rowIds = intArrayOf(
    R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4,
    R.id.row_5, R.id.row_6, R.id.row_7, R.id.row_8, R.id.row_9,
)
private val whenIds = intArrayOf(
    R.id.row_0_when, R.id.row_1_when, R.id.row_2_when, R.id.row_3_when,
    R.id.row_4_when, R.id.row_5_when, R.id.row_6_when, R.id.row_7_when,
    R.id.row_8_when, R.id.row_9_when,
)
private val whatIds = intArrayOf(
    R.id.row_0_what, R.id.row_1_what, R.id.row_2_what, R.id.row_3_what,
    R.id.row_4_what, R.id.row_5_what, R.id.row_6_what, R.id.row_7_what,
    R.id.row_8_what, R.id.row_9_what,
)
