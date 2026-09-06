package io.blockshake.ledger;

import android.app.Activity;
import android.content.Context;
import android.hardware.usb.UsbManager;


import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.blockshake.ledger.operations.CloseOperation;
import io.blockshake.ledger.operations.ConnectOperation;
import io.blockshake.ledger.operations.ConnectionInfoOperation;
import io.blockshake.ledger.operations.ExchangeApduOperation;
import io.blockshake.ledger.operations.GetDevicesOperation;
import io.blockshake.ledger.operations.HasPermissionOperation;
import io.blockshake.ledger.operations.MethodCallRegistry;
import io.blockshake.ledger.operations.RequestPermissionOperation;
import io.blockshake.ledger.operations.TransferInOperation;
import io.blockshake.ledger.operations.TransferOutOperation;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * Flutter plugin entry. Uses {@link Activity} when available for USB permission
 * dialogs (application context alone is unreliable on some OEMs).
 *
 * <p>{@link LedgerManager} is a process-wide singleton so the UI engine and the
 * background-service engine share the same USB session (codebaseOne keeps one
 * Transport handle the same way).
 */
public class LedgerUsbPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {



    private MethodChannel channel;
    private Context appContext;
    @Nullable
    private Activity activity;
    private MethodCallRegistry registry;
    private LedgerManager ledgerManager;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "ledger_usb");
        channel.setMethodCallHandler(this);
        appContext = binding.getApplicationContext();
        UsbManager usbManager =
                (UsbManager) appContext.getSystemService(Context.USB_SERVICE);
        // Singleton: must not create a fresh empty manager per FlutterEngine.
        ledgerManager = LedgerManager.getInstance(usbManager);
        registry = buildRegistry(ledgerManager);
        LedgerLog.i( "plugin attached to engine, manager connected="
                + ledgerManager.isConnected());
    }

    private static MethodCallRegistry buildRegistry(LedgerManager manager) {
        MethodCallRegistry reg = new MethodCallRegistry();
        reg.registerMethodCall("getDevices", new GetDevicesOperation(manager));
        reg.registerMethodCall("requestPermission", new RequestPermissionOperation(manager));
        reg.registerMethodCall("hasPermission", new HasPermissionOperation(manager));
        reg.registerMethodCall("open", new ConnectOperation(manager));
        reg.registerMethodCall("close", new CloseOperation(manager));
        reg.registerMethodCall("transferIn", new TransferInOperation(manager));
        reg.registerMethodCall("transferOut", new TransferOutOperation(manager));
        reg.registerMethodCall("connectionInfo", new ConnectionInfoOperation(manager));
        reg.registerMethodCall("exchangeApdu", new ExchangeApduOperation(manager));
        return reg;
    }

    /** Prefer Activity for permission UI; fall back to application context. */
    private Context effectiveContext() {
        if (activity != null) {
            return activity;
        }
        return appContext;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        registry.onMethodCall(effectiveContext(), call, result);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // Do NOT close the USB session here. The background Flutter engine
        // (watcher) also attaches/detaches this plugin and would wipe a live
        // session opened by the UI isolate — that caused "Not connected".
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        channel = null;
        if (registry != null) {
            registry.clear();
        }
        registry = null;
        ledgerManager = null;
        appContext = null;
        LedgerLog.i( "plugin detached from engine (USB session left open if any)");
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        LedgerLog.i( "plugin attached to activity " + activity.getClass().getSimpleName());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
}
