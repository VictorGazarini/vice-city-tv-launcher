package com.gathin.tvhome;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.LinearGradient;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.drawable.Drawable;
import android.view.View;
import android.view.animation.DecelerateInterpolator;

/**
 * Vice City: the selection belongs to the card itself. As the card's foreground it grows with the zoom; the pink
 * border and the badge fade in, a streak of light crosses the card once, and unselected cards stay slightly dimmed.
 */
class SelectionRing extends Drawable {

    static final int PINK = 0xFB84D0;

    private final View card;
    private final float density;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint shinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF rect = new RectF();
    private final Matrix matrix = new Matrix();
    private final String badge;
    private LinearGradient shine;
    private int shineWidth;

    private ValueAnimator levelAnimator;
    private ValueAnimator shineAnimator;
    /** 0 = unselected, 1 = fully selected. */
    private float level;
    /** Position of the light streak, 0..1; negative while there is none. */
    private float sweep = -1f;

    SelectionRing(View card) {
        this.card = card;
        Context context = card.getContext();
        density = context.getResources().getDisplayMetrics().density;
        badge = "● " + context.getResources().getString(R.string.vc_badge_open);
        text.setTextSize(9f * density);
        text.setTypeface(context.getResources().getFont(R.font.barlow_bold));
        text.setLetterSpacing(0.16f);
    }

    float level() {
        return level;
    }

    void select(boolean selected, boolean animate) {
        if (levelAnimator != null) levelAnimator.cancel();
        if (shineAnimator != null) shineAnimator.cancel();
        sweep = -1f;
        float target = selected ? 1f : 0f;
        if (!animate) {
            level = target;
            redraw();
            return;
        }
        levelAnimator = ValueAnimator.ofFloat(level, target);
        levelAnimator.setDuration(selected ? 240 : 170);
        levelAnimator.setInterpolator(new DecelerateInterpolator(1.4f));
        levelAnimator.addUpdateListener(a -> {
            level = (float) a.getAnimatedValue();
            redraw();
        });
        levelAnimator.start();
        if (selected) {
            shineAnimator = ValueAnimator.ofFloat(0f, 1f);
            shineAnimator.setStartDelay(70);
            shineAnimator.setDuration(420);
            shineAnimator.addUpdateListener(a -> {
                float v = (float) a.getAnimatedValue();
                sweep = v >= 1f ? -1f : v;
                redraw();
            });
            shineAnimator.start();
        }
    }

    /** The card redraws, and so does the grid behind it: the outer glow is painted there (SelectionGlow). */
    private void redraw() {
        invalidateSelf();
        card.invalidate();
        if (card.getParent() != null && card.getParent().getParent() instanceof View) {
            ((View) card.getParent().getParent()).invalidate();
        }
    }

    @Override
    public void draw(Canvas canvas) {
        Rect b = getBounds();
        if (b.isEmpty()) return;
        float radius = AppAdapter.cornerRadius(b.width(), density);
        paint.setShader(null);

        if (level < 1f) {
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(Math.round(0x3C * (1f - level)) << 24 | 0x14111F);
            canvas.drawRect(b, paint);
        }

        if (sweep >= 0f) {
            if (shine == null || shineWidth != b.width()) {
                shineWidth = b.width();
                shine = new LinearGradient(0, 0, shineWidth * 0.45f, shineWidth * 0.12f,
                        new int[]{0x00FFFFFF, 0x66FFFFFF, 0x00FFFFFF}, null, Shader.TileMode.CLAMP);
            }
            matrix.setTranslate(b.left - b.width() * 0.5f + sweep * b.width() * 1.6f, 0);
            shine.setLocalMatrix(matrix);
            shinePaint.setShader(shine);
            canvas.drawRect(b, shinePaint);
        }

        if (level <= 0.01f) return;
        // Borda rosa: engrossa enquanto o cartao e selecionado.
        paint.setStyle(Paint.Style.STROKE);
        float width = (1f + 2f * level) * density;
        paint.setStrokeWidth(width);
        paint.setColor(Math.round(255 * level) << 24 | PINK);
        rect.set(b);
        rect.inset(width / 2f, width / 2f);
        canvas.drawRoundRect(rect, radius - width / 2f, radius - width / 2f, paint);
        // Fio claro por dentro, para a borda aparecer tambem sobre banners rosa ou brancos.
        paint.setStrokeWidth(density);
        paint.setColor(Math.round(0x80 * level) << 24 | 0x14111F);
        rect.set(b);
        rect.inset(width + density / 2f, width + density / 2f);
        canvas.drawRoundRect(rect, radius - width, radius - width, paint);

        // Selo "ABRIR": sobe e aparece.
        float w = text.measureText(badge) + 12f * density;
        float h = 15f * density;
        float lift = (1f - level) * 7f * density;
        rect.set(b.right - 8f * density - w, b.bottom - 8f * density - h + lift,
                b.right - 8f * density, b.bottom - 8f * density + lift);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(Math.round(0xE6 * level) << 24 | 0x14111F);
        canvas.drawRoundRect(rect, 3f * density, 3f * density, paint);
        text.setColor(Math.round(255 * level) << 24 | PINK);
        Paint.FontMetrics fm = text.getFontMetrics();
        canvas.drawText(badge, rect.left + 6f * density, rect.centerY() - (fm.ascent + fm.descent) / 2f, text);
    }

    @Override
    public void setAlpha(int alpha) {
    }

    @Override
    public void setColorFilter(ColorFilter filter) {
    }

    @Override
    public int getOpacity() {
        return PixelFormat.TRANSLUCENT;
    }
}
