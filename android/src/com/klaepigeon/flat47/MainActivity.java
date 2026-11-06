package com.klaepigeon.flat47;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;

/**
 * Flat 47 on Android: the web build in a full-screen WebView, plus a bridge that reads
 * game controllers from Android's own input system and hands them to the page
 * (window.__nativePad), because WebView's Gamepad API support varies by device.
 */
public class MainActivity extends Activity {
    private WebView web;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final float[] axes = new float[6]; // lx, ly, rx, ry, lt, rt
    private int mask = 0, hatMask = 0;
    private boolean padSeen = false, sendQueued = false;
    private int lastPadId = -1;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON | WindowManager.LayoutParams.FLAG_FULLSCREEN);
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(true);
        web.setWebChromeClient(new WebChromeClient());
        web.setBackgroundColor(0xFF000000);
        web.addJavascriptInterface(new Bridge(), "FlatNative");
        web.setFocusable(true);
        web.setFocusableInTouchMode(true);
        setContentView(web);
        web.loadUrl("file:///android_asset/index.html");
        immersive();
        heartbeat();
    }

    private void immersive() {
        web.setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) immersive();
    }

    @Override
    protected void onPause() {
        js("window.__pauseGame && window.__pauseGame()");
        web.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        web.onResume();
        immersive();
    }

    private void js(String code) { if (web != null) web.evaluateJavascript(code, null); }

    // ---------------------------------------------------------------- controller
    private static boolean isPad(int source) {
        return (source & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
                || (source & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
                || (source & InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD;
    }

    private static int bit(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_BUTTON_A: return 0;
            case KeyEvent.KEYCODE_BUTTON_B: return 1;
            case KeyEvent.KEYCODE_BUTTON_X: return 2;
            case KeyEvent.KEYCODE_BUTTON_Y: return 3;
            case KeyEvent.KEYCODE_BUTTON_L1: return 4;
            case KeyEvent.KEYCODE_BUTTON_R1: return 5;
            case KeyEvent.KEYCODE_BUTTON_L2: return 6;
            case KeyEvent.KEYCODE_BUTTON_R2: return 7;
            case KeyEvent.KEYCODE_BUTTON_SELECT: return 8;
            case KeyEvent.KEYCODE_BUTTON_START: return 9;
            case KeyEvent.KEYCODE_BUTTON_THUMBL: return 10;
            case KeyEvent.KEYCODE_BUTTON_THUMBR: return 11;
            case KeyEvent.KEYCODE_DPAD_UP: return 12;
            case KeyEvent.KEYCODE_DPAD_DOWN: return 13;
            case KeyEvent.KEYCODE_DPAD_LEFT: return 14;
            case KeyEvent.KEYCODE_DPAD_RIGHT: return 15;
            case KeyEvent.KEYCODE_DPAD_CENTER: return 0;
            default: return -1;
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int code = e.getKeyCode();
        boolean pad = isPad(e.getSource());
        // many controllers send B as BACK; on a pad that's B, on the phone it's the back gesture
        if (code == KeyEvent.KEYCODE_BACK && pad && e.getDevice() != null && !e.getDevice().isVirtual()) code = KeyEvent.KEYCODE_BUTTON_B;
        if (code == KeyEvent.KEYCODE_BACK) {
            if (e.getAction() == KeyEvent.ACTION_UP) js("window.__back && window.__back()");
            return true;
        }
        int b = pad ? bit(code) : -1;
        if (b >= 0) {
            padSeen = true; lastPadId = e.getDeviceId();
            if (e.getAction() == KeyEvent.ACTION_DOWN) mask |= (1 << b); else if (e.getAction() == KeyEvent.ACTION_UP) mask &= ~(1 << b);
            queue();
            return true;
        }
        return super.dispatchKeyEvent(e);
    }

    private static float axis(MotionEvent e, int a) {
        InputDevice d = e.getDevice();
        if (d == null || d.getMotionRange(a, e.getSource()) == null) return 0f;
        return e.getAxisValue(a);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent e) {
        if ((e.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK && e.getAction() == MotionEvent.ACTION_MOVE) {
            padSeen = true; lastPadId = e.getDeviceId();
            axes[0] = axis(e, MotionEvent.AXIS_X);
            axes[1] = axis(e, MotionEvent.AXIS_Y);
            // right stick: Z/RZ on most pads, RX/RY on some
            float rx = axis(e, MotionEvent.AXIS_Z), ry = axis(e, MotionEvent.AXIS_RZ);
            if (e.getDevice() != null && e.getDevice().getMotionRange(MotionEvent.AXIS_RX) != null && e.getDevice().getMotionRange(MotionEvent.AXIS_Z) == null) {
                rx = axis(e, MotionEvent.AXIS_RX); ry = axis(e, MotionEvent.AXIS_RY);
            }
            axes[2] = rx; axes[3] = ry;
            axes[4] = Math.max(axis(e, MotionEvent.AXIS_LTRIGGER), axis(e, MotionEvent.AXIS_BRAKE));
            axes[5] = Math.max(axis(e, MotionEvent.AXIS_RTRIGGER), axis(e, MotionEvent.AXIS_GAS));
            float hx = axis(e, MotionEvent.AXIS_HAT_X), hy = axis(e, MotionEvent.AXIS_HAT_Y);
            hatMask = (hy < -0.5f ? 1 << 12 : 0) | (hy > 0.5f ? 1 << 13 : 0) | (hx < -0.5f ? 1 << 14 : 0) | (hx > 0.5f ? 1 << 15 : 0);
            queue();
            return true;
        }
        return super.dispatchGenericMotionEvent(e);
    }

    // coalesce: at most one push to the page per frame
    private void queue() {
        if (sendQueued) return;
        sendQueued = true;
        handler.postDelayed(new Runnable() { public void run() { sendQueued = false; send(); } }, 12);
    }

    private void send() {
        js(String.format(java.util.Locale.US, "window.__nativePad&&window.__nativePad(%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d)",
                axes[0], axes[1], axes[2], axes[3], axes[4], axes[5], mask | hatMask));
    }

    // Android only reports changes; the page drops a pad it hasn't heard from in a few seconds
    private void heartbeat() {
        handler.postDelayed(new Runnable() { public void run() { if (padSeen) send(); heartbeat(); } }, 500);
    }

    // ---------------------------------------------------------------- page -> app
    private class Bridge {
        @JavascriptInterface
        public void rumble(int ms, int amplitude) {
            try {
                Vibrator v = null;
                InputDevice d = InputDevice.getDevice(lastPadId);
                if (d != null && Build.VERSION.SDK_INT >= 31) {
                    VibratorManager vm = d.getVibratorManager();
                    int[] ids = vm.getVibratorIds();
                    if (ids.length > 0) v = vm.getVibrator(ids[0]);
                }
                if (v == null && d != null && Build.VERSION.SDK_INT < 31) v = d.getVibrator();
                if (v == null || !v.hasVibrator()) return; // don't buzz the phone, only the controller
                int amp = Math.max(1, Math.min(255, amplitude));
                if (Build.VERSION.SDK_INT >= 26) v.vibrate(VibrationEffect.createOneShot(ms, amp)); else v.vibrate(ms);
            } catch (Throwable t) { /* no rumble */ }
        }
    }
}
