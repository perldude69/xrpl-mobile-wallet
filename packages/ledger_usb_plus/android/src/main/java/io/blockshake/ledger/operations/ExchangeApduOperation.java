package io.blockshake.ledger.operations;

import android.content.Context;
import io.blockshake.ledger.LedgerException;
import io.blockshake.ledger.LedgerLog;
import io.blockshake.ledger.LedgerManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Atomic HID-framed APDU exchange on the process-wide {@link LedgerManager}.
 * Matches desktop codebaseOne flow: keep one session, send full APDU, return response.
 */
public class ExchangeApduOperation extends UsbMethodCallOperation {

    private final LedgerManager manager;

    public ExchangeApduOperation(LedgerManager manager) {
        super(manager.usbManager);
        this.manager = manager;
    }

    @Override
    public void onMethodCall(Context context, MethodCall methodCall, MethodChannel.Result result) {
        byte[] apdu = methodCall.argument("apdu");
        String identifier = methodCall.argument("identifier");
        Integer timeout = methodCall.argument("timeout");
        if (apdu == null || apdu.length < 4) {
            result.error("60010", "Missing or short APDU", null);
            return;
        }
        int timeoutMs = timeout != null ? timeout : 120_000;
        if (identifier == null || identifier.isEmpty()) {
            identifier = "auto";
        }
        try {
            LedgerLog.i( "exchangeApdu op: len=" + apdu.length + " id=" + identifier);
            byte[] response = manager.exchangeApdu(apdu, identifier, timeoutMs);
            result.success(response);
        } catch (LedgerException ex) {
            LedgerLog.e( "exchangeApdu failed: " + ex.getMessage());
            result.error(ex.getErrorCode(), ex.getMessage(), null);
        } catch (Exception ex) {
            LedgerLog.e( "exchangeApdu unexpected", ex);
            result.error("60099", ex.getMessage(), null);
        }
    }
}
