package io.blockshake.ledger.operations;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import io.blockshake.ledger.LedgerLog;
import io.blockshake.ledger.LedgerManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Request temporary USB host permission for a Ledger device.
 *
 * <p>Android 12+ requires {@link PendingIntent#FLAG_MUTABLE} so UsbManager can
 * attach {@link UsbManager#EXTRA_PERMISSION_GRANTED}. There is no separate
 * install-time {@code USB_PERMISSION} that unlocks devices — only this dialog.
 */
public class RequestPermissionOperation extends UsbMethodCallOperation {

    static final String ACTION_USB_PERMISSION = "io.blockshake.ledger.USB_PERMISSION";

    private final LedgerManager manager;

    public RequestPermissionOperation(LedgerManager manager) {
        super(manager.usbManager);
        this.manager = manager;
    }

    @Override
    public void onMethodCall(Context context, MethodCall methodCall, MethodChannel.Result result) {
        String identifier = methodCall.argument("identifier");
        UsbDevice device = manager.findDevice(identifier);
        if (device == null) {
            device = manager.findFirstLedger();
        }
        if (device == null) {
            LedgerLog.w( "requestPermission: no Ledger in device list");
            result.success(false);
            return;
        }

        if (usbManager.hasPermission(device)) {
            LedgerLog.i( "requestPermission: already granted for " + device.getDeviceName());
            result.success(true);
            return;
        }

        final UsbDevice target = device;
        final Handler main = new Handler(Looper.getMainLooper());
        final boolean[] answered = {false};

        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context ctx, Intent intent) {
                if (answered[0]) {
                    return;
                }
                if (intent == null || !ACTION_USB_PERMISSION.equals(intent.getAction())) {
                    return;
                }
                answered[0] = true;
                try {
                    ctx.unregisterReceiver(this);
                } catch (Exception ignored) {
                }

                boolean grantedExtra =
                        intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false);
                boolean hasPerm = false;
                try {
                    hasPerm = usbManager.hasPermission(target);
                    // Device may have re-enumerated; check any Ledger.
                    if (!hasPerm) {
                        UsbDevice again = manager.findFirstLedger();
                        if (again != null) {
                            hasPerm = usbManager.hasPermission(again);
                        }
                    }
                } catch (Exception e) {
                    LedgerLog.w( "hasPermission check failed", e);
                }
                final boolean granted = grantedExtra || hasPerm;
                LedgerLog.i( "requestPermission result: extra=" + grantedExtra
                        + " hasPermission=" + hasPerm + " → " + granted);
                main.post(() -> result.success(granted));
            }
        };

        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        // EXPORTED: system delivers the PendingIntent result; NOT_EXPORTED breaks some OEMs.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            context.registerReceiver(receiver, filter);
        }

        LedgerLog.i( "requestPermission: dialog for " + device.getDeviceName()
                + " ctx=" + context.getClass().getSimpleName());
        usbManager.requestPermission(device, getPendingIntent(context));

        // Safety timeout so the Flutter Future does not hang forever.
        main.postDelayed(() -> {
            if (answered[0]) {
                return;
            }
            answered[0] = true;
            try {
                context.unregisterReceiver(receiver);
            } catch (Exception ignored) {
            }
            boolean hasPerm = usbManager.hasPermission(target);
            LedgerLog.w( "requestPermission: timeout, hasPermission=" + hasPerm);
            result.success(hasPerm);
        }, 60_000);
    }

    PendingIntent getPendingIntent(Context context) {
        Intent intent = new Intent(ACTION_USB_PERMISSION);
        intent.setPackage(context.getPackageName());

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Required: system must add EXTRA_PERMISSION_GRANTED.
            flags |= PendingIntent.FLAG_MUTABLE;
        }

        return PendingIntent.getBroadcast(context, 0, intent, flags);
    }
}
