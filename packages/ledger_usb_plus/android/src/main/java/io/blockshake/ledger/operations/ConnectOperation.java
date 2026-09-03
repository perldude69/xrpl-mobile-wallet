package io.blockshake.ledger.operations;

import android.content.Context;
import android.util.Log;

import io.blockshake.ledger.LedgerException;
import io.blockshake.ledger.LedgerManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ConnectOperation extends UsbMethodCallOperation {

    private static final String TAG = "LedgerUSB";
    private final LedgerManager manager;

    public ConnectOperation(LedgerManager manager) {
        super(manager.usbManager);
        this.manager = manager;
    }

    @Override
    public void onMethodCall(Context context, MethodCall methodCall, MethodChannel.Result result) {
        String identifier = methodCall.argument("identifier");
        try {
            Log.i(TAG, "connect open identifier=" + identifier);
            this.manager.open(identifier);
            Log.i(TAG, "connect open ok connected=" + manager.isConnected()
                    + " info=" + manager.connectionInfo());
            result.success(true);
        } catch (LedgerException ex) {
            Log.e(TAG, "connect open failed: " + ex.getMessage());
            this.manager.gracefullyReset();
            result.error(String.valueOf(ex.getErrorCode()), ex.getMessage(), null);
        } catch (Exception ex) {
            Log.e(TAG, "connect open unexpected", ex);
            this.manager.gracefullyReset();
            result.error("60099", ex.getMessage(), null);
        }
    }
}
