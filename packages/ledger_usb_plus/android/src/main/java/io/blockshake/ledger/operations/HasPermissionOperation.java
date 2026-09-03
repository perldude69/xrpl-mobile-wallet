package io.blockshake.ledger.operations;

import android.content.Context;

import io.blockshake.ledger.LedgerManager;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class HasPermissionOperation extends UsbMethodCallOperation {

    private final LedgerManager manager;

    public HasPermissionOperation(LedgerManager manager) {
        super(manager.usbManager);
        this.manager = manager;
    }

    @Override
    public void onMethodCall(Context context, MethodCall methodCall, MethodChannel.Result result) {
        String identifier = methodCall.argument("identifier");
        result.success(manager.hasPermission(identifier));
    }
}
