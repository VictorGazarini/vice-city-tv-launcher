package com.gathin.tvhome;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

/**
 * Vice City: the soft pink light around the selected card, painted under the cards. It follows each card's own zoom,
 * so it grows out of the newly selected card while it dies down on the previous one.
 */
class SelectionGlow extends RecyclerView.ItemDecoration {

    private static final int RINGS = 10;

    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final float density;

    SelectionGlow(float density) {
        this.density = density;
        paint.setStyle(Paint.Style.STROKE);
    }

    @Override
    public void onDraw(@NonNull Canvas canvas, @NonNull RecyclerView parent, @NonNull RecyclerView.State state) {
        for (int i = 0; i < parent.getChildCount(); i++) {
            View item = parent.getChildAt(i);
            View card = item.findViewById(R.id.card);
            if (card == null || card.getWidth() == 0) continue;
            Drawable foreground = card.getForeground();
            if (!(foreground instanceof SelectionRing)) continue;
            float level = ((SelectionRing) foreground).level();
            if (level <= 0.01f) continue;
            float w = card.getWidth() * card.getScaleX();
            float h = card.getHeight() * card.getScaleY();
            float cx = item.getX() + card.getLeft() + card.getTranslationX() + card.getWidth() / 2f;
            float cy = item.getY() + card.getTop() + card.getTranslationY() + card.getHeight() / 2f;
            float radius = AppAdapter.cornerRadius(card.getWidth(), density) * card.getScaleX();
            float step = 1.3f * density;
            paint.setStrokeWidth(step + 0.8f);
            for (int ring = 0; ring < RINGS; ring++) {
                float out = step * (ring + 0.5f);
                float fade = 1f - (float) ring / RINGS;
                paint.setColor(Math.round(0xA0 * fade * fade * level) << 24 | SelectionRing.PINK);
                rect.set(cx - w / 2f - out, cy - h / 2f - out, cx + w / 2f + out, cy + h / 2f + out);
                canvas.drawRoundRect(rect, radius + out, radius + out, paint);
            }
        }
    }
}
