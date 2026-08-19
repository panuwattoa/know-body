package app.knowbody.knowbody

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: the KnowBody calorie ring + streak. Tapping it opens the app. */
class KnowBodyWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.knowbody_widget)
            val kcalLeft = widgetData.getInt("kcalLeft", 0)
            val pct = widgetData.getInt("pct", 0).coerceIn(0, 100) / 100f
            val streak = widgetData.getInt("streak", 0)

            views.setImageViewBitmap(R.id.kb_ring, ring(kcalLeft, pct))
            views.setTextViewText(R.id.kb_streak, "🔥 $streak")

            val pending = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.kb_root, pending)

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun ring(kcalLeft: Int, pct: Float): Bitmap {
        val s = 400
        val bmp = Bitmap.createBitmap(s, s, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val stroke = s * 0.12f
        val cx = s / 2f
        val r = cx - stroke

        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#303A1C"); style = Paint.Style.STROKE; strokeWidth = stroke
        }
        c.drawCircle(cx, cx, r, track)

        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#D8FB4F"); style = Paint.Style.STROKE
            strokeWidth = stroke; strokeCap = Paint.Cap.ROUND
        }
        c.drawArc(cx - r, cx - r, cx + r, cx + r, -90f, pct.coerceIn(0f, 1f) * 360f, false, arc)

        val num = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE; textAlign = Paint.Align.CENTER
            textSize = s * 0.26f; typeface = Typeface.DEFAULT_BOLD
        }
        c.drawText(kcalLeft.toString(), cx, cx + num.textSize * 0.32f - s * 0.03f, num)

        val lbl = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(150, 255, 255, 255); textAlign = Paint.Align.CENTER; textSize = s * 0.075f
        }
        c.drawText("KCAL LEFT", cx, cx + s * 0.17f, lbl)
        return bmp
    }
}
