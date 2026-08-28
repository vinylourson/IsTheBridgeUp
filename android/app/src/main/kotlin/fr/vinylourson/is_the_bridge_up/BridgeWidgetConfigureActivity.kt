package fr.vinylourson.is_the_bridge_up

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button

/**
 * Shown when the widget is placed, and again from the widget's own settings.
 *
 * The only thing to configure is how many closures to list. Size is Android's
 * own resize handles, and the provider clamps the list to whatever the chosen
 * size can actually show.
 */
class BridgeWidgetConfigureActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Cancelled unless a choice is made: leaving this activity any other
        // way must not drop a half-configured widget on the home screen.
        setResult(RESULT_CANCELED)

        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_configure)

        val current = BridgeWidgetProvider.loadRowCount(this, widgetId)
        val choices = listOf(
            R.id.choice_1 to 1,
            R.id.choice_3 to 3,
            R.id.choice_5 to 5,
            R.id.choice_10 to 10,
        )
        for ((viewId, count) in choices) {
            val button = findViewById<Button>(viewId)
            if (count == current) button.alpha = 1.0f else button.alpha = 0.65f
            button.setOnClickListener { commit(count) }
        }
    }

    private fun commit(rows: Int) {
        BridgeWidgetProvider.saveRowCount(this, widgetId, rows)

        // Draw it immediately: without this the widget stays blank until the
        // next update broadcast, which can be half an hour away.
        val manager = AppWidgetManager.getInstance(this)
        BridgeWidgetProvider().onUpdate(
            this,
            manager,
            intArrayOf(widgetId),
            getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE),
        )

        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
        )
        finish()
    }
}
