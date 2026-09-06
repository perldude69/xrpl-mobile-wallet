package io.blockshake.ledger.operations;

import android.content.Context;
import io.blockshake.ledger.LedgerException;
import io.blockshake.ledger.LedgerLog;
import io.blockshake.ledger.LedgerManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ConnectOperation extends UsbMethodCallOperation {

    private final LedgerManager manager;

    public ConnectOperation(LedgerManager manager) {
        super(manager.usbManager);
        this.manager = manager;
    }

    @Override
    public void onMethodCall(Context context, MethodCall methodCall, MethodChannel.Result result) {
        String identifier = methodCall.argument("identifier");
        try {
            LedgerLog.i( "connect open identifier=" + identifier);
            this.manager.open(identifier);
            LedgerLog.i( "connect open ok connected=" + manager.isConnected()
                    + " info=" + manager.connectionInfo());
            result.success(true);
        } catch (LedgerException ex) {
            LedgerLog.e( "connect open failed: " + ex.getMessage());
            this.manager.gracefullyReset();
            result.error(String.valueOf(ex.getErrorCode()), ex.getMessage(), null);
        } catch (Exception ex) {
            LedgerLog.e( "connect open unexpected", ex);
            this.manager.gracefullyReset();
            result.error("60099", ex.getMessage(), null);
        }
    }
}
