package io.blockshake.ledger;

import android.util.Log;

/**
 * USB session logs. Release builds emit nothing (no device names, APDU
 * lengths, or HID channels). Debug builds keep the LedgerUSB tag.
 */
public final class LedgerLog {
    private static final String TAG = "LedgerUSB";

    private LedgerLog() {}

    public static void i(String msg) {
        if (BuildConfig.DEBUG) {
            Log.i(TAG, msg);
        }
    }

    public static void w(String msg) {
        if (BuildConfig.DEBUG) {
            Log.w(TAG, msg);
        }
    }

    public static void w(String msg, Throwable t) {
        if (BuildConfig.DEBUG) {
            Log.w(TAG, msg, t);
        }
    }

    public static void e(String msg) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, msg);
        }
    }

    public static void e(String msg, Throwable t) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, msg, t);
        }
    }
}
