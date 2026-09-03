package io.blockshake.ledger;

import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.util.Log;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * Process-wide USB host session for Ledger devices.
 *
 * <p>Must be a singleton: Flutter background isolates also load plugins and would
 * otherwise each hold a separate (empty) connection, producing "Not connected"
 * on transfer after open succeeded on another engine instance.
 *
 * <p>Matches the working desktop path in codebaseOne ({@code @ledgerhq/hw-transport-node-hid}):
 * open once, exchange APDUs on the same handle, close explicitly.
 */
public class LedgerManager {

    private static final String TAG = "LedgerUSB";

    /** Ledger vendor id 0x2c97. */
    public static final int LEDGER_VENDOR_ID = 0x2c97;

    private static final int HID_PACKET_SIZE = 64;
    private static final int HID_TAG = 0x05;

    private static volatile LedgerManager instance;

    public final UsbManager usbManager;

    private UsbDevice device;
    private UsbDeviceConnection connection;
    private UsbInterface usbInterface;
    private UsbEndpoint usbEndpointReadIn;
    private UsbEndpoint usbEndpointWriteOut;

    /** Serialize open / exchange / close across Flutter engines. */
    private final Object lock = new Object();

    private LedgerManager(UsbManager usbManager) {
        this.usbManager = usbManager;
    }

    /**
     * Process-wide instance. Safe when UI + background Flutter engines both load the plugin.
     */
    public static LedgerManager getInstance(UsbManager usbManager) {
        if (instance == null) {
            synchronized (LedgerManager.class) {
                if (instance == null) {
                    instance = new LedgerManager(usbManager);
                    Log.i(TAG, "LedgerManager singleton created");
                }
            }
        }
        return instance;
    }

    public boolean hasPermission(String identifier) {
        UsbDevice d = findDevice(identifier);
        return d != null && usbManager.hasPermission(d);
    }

    public boolean isConnected() {
        synchronized (lock) {
            return connection != null;
        }
    }

    /**
     * Resolve a device by USB device name key, or by vendor if the bus path changed
     * after re-enumeration (common when opening the XRP app).
     */
    public UsbDevice findDevice(String identifier) {
        if (identifier == null) {
            return null;
        }
        Map<String, UsbDevice> list = usbManager.getDeviceList();
        UsbDevice byKey = list.get(identifier);
        if (byKey != null) {
            return byKey;
        }
        for (UsbDevice d : list.values()) {
            if (d.getVendorId() == LEDGER_VENDOR_ID) {
                Log.w(TAG, "findDevice: key miss for " + identifier
                        + ", falling back to " + d.getDeviceName());
                return d;
            }
        }
        return null;
    }

    public UsbDevice findFirstLedger() {
        for (UsbDevice d : usbManager.getDeviceList().values()) {
            if (d.getVendorId() == LEDGER_VENDOR_ID) {
                return d;
            }
        }
        return null;
    }

    /**
     * Open a USB connection and claim the HID (or bulk) interface.
     *
     * @param identifier Device name key from {@link UsbManager#getDeviceList()},
     *                   or empty/"auto" to pick the first Ledger.
     */
    public void open(String identifier) throws LedgerException {
        synchronized (lock) {
            openLocked(identifier);
        }
    }

    private void openLocked(String identifier) throws LedgerException {
        // Drop any previous handle first.
        closeQuietlyLocked();

        UsbDevice target;
        if (identifier == null || identifier.isEmpty() || "auto".equals(identifier)) {
            target = findFirstLedger();
        } else {
            target = findDevice(identifier);
        }

        if (target == null) {
            throw new LedgerException(
                    0x60000,
                    "Ledger not found on USB. Unlock it, open the XRP app, "
                            + "and use a data-capable OTG cable.");
        }

        Log.i(TAG, "open: name=" + target.getDeviceName()
                + " vid=0x" + Integer.toHexString(target.getVendorId())
                + " pid=0x" + Integer.toHexString(target.getProductId())
                + " ifaces=" + target.getInterfaceCount()
                + " hasPerm=" + usbManager.hasPermission(target));

        if (!usbManager.hasPermission(target)) {
            throw new LedgerException(
                    0x60001,
                    "No USB permission for this Ledger. Tap Allow when prompted.");
        }

        UsbDeviceConnection conn = usbManager.openDevice(target);
        if (conn == null) {
            throw new LedgerException(
                    0x60001,
                    "openDevice returned null (permission missing or device busy). "
                            + "Close Ledger Live, unplug/replug, open XRP app, retry.");
        }

        InterfacePick pick = pickInterface(target);
        if (pick == null) {
            conn.close();
            throw new LedgerException(
                    0x60003,
                    "No usable USB interface on Ledger "
                            + "(need HID or bulk IN+OUT). ifaces="
                            + describeInterfaces(target));
        }

        Log.i(TAG, "open: claiming iface=" + pick.usbInterface.getId()
                + " class=" + pick.usbInterface.getInterfaceClass()
                + " inEp=" + pick.in.getEndpointNumber()
                + " outEp=" + pick.out.getEndpointNumber()
                + " inType=" + pick.in.getType()
                + " outType=" + pick.out.getType());

        // force=true detaches kernel HID driver so userspace can talk APDUs.
        boolean claimed = conn.claimInterface(pick.usbInterface, true);
        if (!claimed) {
            conn.close();
            throw new LedgerException(
                    0x60004,
                    "Unable to claim USB interface "
                            + pick.usbInterface.getId()
                            + ". Close Ledger Live / other USB wallets and retry.");
        }

        this.device = target;
        this.connection = conn;
        this.usbInterface = pick.usbInterface;
        this.usbEndpointReadIn = pick.in;
        this.usbEndpointWriteOut = pick.out;

        Log.i(TAG, "open: success connected=" + (connection != null)
                + " thread=" + Thread.currentThread().getName());
    }

    /**
     * Ensure a live session: open if needed (same pattern as desktop Transport.create).
     */
    public void ensureOpen(String identifier) throws LedgerException {
        synchronized (lock) {
            if (connection != null) {
                return;
            }
            openLocked(identifier);
        }
    }

    public void close() {
        synchronized (lock) {
            closeQuietlyLocked();
            Log.i(TAG, "close: session cleared");
        }
    }

    public void gracefullyReset() {
        close();
    }

    private void closeQuietlyLocked() {
        try {
            if (connection != null) {
                if (usbInterface != null) {
                    try {
                        connection.releaseInterface(usbInterface);
                    } catch (Exception ignored) {
                    }
                }
                try {
                    connection.close();
                } catch (Exception ignored) {
                }
            }
        } finally {
            connection = null;
            usbInterface = null;
            usbEndpointReadIn = null;
            usbEndpointWriteOut = null;
            device = null;
        }
    }

    public byte[] transferIn(int packetSize, int timeout) throws LedgerException {
        synchronized (lock) {
            if (connection == null) {
                throw notConnected();
            }
            return transferInLocked(packetSize, timeout);
        }
    }

    public int transferOut(byte[] data, int timeout) throws LedgerException {
        synchronized (lock) {
            if (connection == null) {
                throw notConnected();
            }
            return transferOutLocked(data, timeout);
        }
    }

    /**
     * Atomic APDU exchange (HID framed), matching {@code @ledgerhq/hw-transport-node-hid}.
     * Auto-opens if the session was dropped between Dart open() and exchange().
     *
     * @param apdu full APDU bytes (CLA INS P1 P2 Lc Data)
     * @param identifier device key for re-open fallback ("auto" ok)
     * @param timeoutMs per bulk transfer timeout
     * @return raw APDU response including SW1SW2
     */
    public byte[] exchangeApdu(byte[] apdu, String identifier, int timeoutMs)
            throws LedgerException {
        synchronized (lock) {
            if (connection == null) {
                Log.w(TAG, "exchangeApdu: not connected, re-opening…");
                openLocked(identifier == null ? "auto" : identifier);
            }

            int channel = new Random().nextInt(0x10000);
            List<byte[]> blocks = hidPack(apdu, channel, HID_PACKET_SIZE);
            Log.i(TAG, "exchangeApdu: apduLen=" + apdu.length
                    + " blocks=" + blocks.size()
                    + " channel=0x" + Integer.toHexString(channel)
                    + " timeout=" + timeoutMs);

            for (int i = 0; i < blocks.size(); i++) {
                int n = transferOutLocked(blocks.get(i), timeoutMs);
                Log.i(TAG, "exchangeApdu: transferOut block " + i + " wrote=" + n);
                if (n < 0) {
                    // Session may have died; one reopen + retry once.
                    Log.w(TAG, "exchangeApdu: write failed, re-open and retry once");
                    openLocked(identifier == null ? "auto" : identifier);
                    n = transferOutLocked(blocks.get(i), timeoutMs);
                    if (n < 0) {
                        throw new LedgerException(
                                0x60006,
                                "USB write failed after re-open (transferOut=" + n + ")");
                    }
                }
            }

            FrameAcc acc = null;
            int emptyReads = 0;
            final int maxEmpty = 12;
            while (hidComplete(acc) == null) {
                byte[] chunk = transferInLocked(HID_PACKET_SIZE, timeoutMs);
                if (chunk == null || chunk.length == 0) {
                    emptyReads++;
                    Log.w(TAG, "exchangeApdu: empty read " + emptyReads + "/" + maxEmpty);
                    if (emptyReads >= maxEmpty) {
                        throw new LedgerException(
                                0x60007,
                                "No response from Ledger (USB read timed out). "
                                        + "Keep XRP app open and approve on device if prompted.");
                    }
                    continue;
                }
                emptyReads = 0;
                Log.i(TAG, "exchangeApdu: transferIn " + chunk.length + "b");
                try {
                    acc = hidReduce(acc, channel, chunk);
                } catch (IllegalArgumentException e) {
                    throw new LedgerException(
                            0x60008,
                            "USB framing error: " + e.getMessage()
                                    + ". Unplug/replug, open XRP app, retry.");
                }
            }

            byte[] result = hidComplete(acc);
            if (result == null) {
                result = new byte[0];
            }
            Log.i(TAG, "exchangeApdu: response " + result.length + "b");
            return result;
        }
    }

    private LedgerException notConnected() {
        return new LedgerException(
                0x60001,
                "Not connected. Call open after granting USB permission "
                        + "with the XRP app already open on the Ledger.");
    }

    private byte[] transferInLocked(int packetSize, int timeout) throws LedgerException {
        try {
            byte[] buffer = new byte[packetSize];
            // bulkTransfer also works for interrupt endpoints on Android USB host.
            int length = connection.bulkTransfer(
                    usbEndpointReadIn, buffer, buffer.length, timeout);
            if (length < 0) {
                return new byte[0];
            }
            return Arrays.copyOfRange(buffer, 0, length);
        } catch (Exception ex) {
            Log.e(TAG, "transferIn failed", ex);
            // Drop dead session so next call re-opens.
            closeQuietlyLocked();
            throw new LedgerException(0x60006, "Error reading USB endpoint: " + ex.getMessage());
        }
    }

    private int transferOutLocked(byte[] data, int timeout) throws LedgerException {
        try {
            return connection.bulkTransfer(
                    usbEndpointWriteOut, data, data.length, timeout);
        } catch (Exception ex) {
            Log.e(TAG, "transferOut failed", ex);
            closeQuietlyLocked();
            throw new LedgerException(0x60006, "Error writing USB endpoint: " + ex.getMessage());
        }
    }

    public UsbDevice getDevice() {
        synchronized (lock) {
            return device;
        }
    }

    public UsbDeviceConnection getConnection() {
        synchronized (lock) {
            return connection;
        }
    }

    // --- HID framing (same algorithm as @ledgerhq/devices hid-framing) ---

    private static List<byte[]> hidPack(byte[] apdu, int channel, int packetSize) {
        // [apduLen:2 BE][apdu] then pad to block boundaries
        byte[] prefixed = new byte[2 + apdu.length];
        prefixed[0] = (byte) ((apdu.length >> 8) & 0xff);
        prefixed[1] = (byte) (apdu.length & 0xff);
        System.arraycopy(apdu, 0, prefixed, 2, apdu.length);

        int blockSize = packetSize - 5;
        int nbBlocks = (int) Math.ceil(prefixed.length / (double) blockSize);
        int paddedLen = nbBlocks * blockSize;
        // Official JS uses: nbBlocks * blockSize - data.length + 1 zeros
        byte[] data = new byte[paddedLen + 1];
        System.arraycopy(prefixed, 0, data, 0, prefixed.length);

        List<byte[]> blocks = new ArrayList<>(nbBlocks);
        for (int i = 0; i < nbBlocks; i++) {
            byte[] block = new byte[packetSize];
            block[0] = (byte) ((channel >> 8) & 0xff);
            block[1] = (byte) (channel & 0xff);
            block[2] = (byte) HID_TAG;
            block[3] = (byte) ((i >> 8) & 0xff);
            block[4] = (byte) (i & 0xff);
            System.arraycopy(data, i * blockSize, block, 5, blockSize);
            blocks.add(block);
        }
        return blocks;
    }

    private static class FrameAcc {
        final byte[] data;
        final int length;
        final int sequence;

        FrameAcc(byte[] data, int length, int sequence) {
            this.data = data;
            this.length = length;
            this.sequence = sequence;
        }
    }

    private static byte[] hidComplete(FrameAcc acc) {
        if (acc == null) {
            return null;
        }
        if (acc.length == acc.data.length) {
            return acc.data;
        }
        return null;
    }

    private static FrameAcc hidReduce(FrameAcc acc, int channel, byte[] chunk) {
        if (chunk.length < 5) {
            throw new IllegalArgumentException("chunk too short (" + chunk.length + ")");
        }
        int gotChannel = ((chunk[0] & 0xff) << 8) | (chunk[1] & 0xff);
        if (gotChannel != channel) {
            throw new IllegalArgumentException(
                    "Invalid channel 0x" + Integer.toHexString(gotChannel));
        }
        if ((chunk[2] & 0xff) != HID_TAG) {
            throw new IllegalArgumentException(
                    "Invalid tag 0x" + Integer.toHexString(chunk[2] & 0xff));
        }
        int gotSeq = ((chunk[3] & 0xff) << 8) | (chunk[4] & 0xff);
        int sequence = acc == null ? 0 : acc.sequence;
        if (gotSeq != sequence) {
            throw new IllegalArgumentException(
                    "Invalid sequence " + gotSeq + " (want " + sequence + ")");
        }

        int dataLength;
        int offset;
        byte[] prev = acc == null ? new byte[0] : acc.data;
        if (acc == null) {
            if (chunk.length < 7) {
                throw new IllegalArgumentException("first chunk too short");
            }
            dataLength = ((chunk[5] & 0xff) << 8) | (chunk[6] & 0xff);
            offset = 7;
        } else {
            dataLength = acc.length;
            offset = 5;
        }

        byte[] chunkData = Arrays.copyOfRange(chunk, offset, chunk.length);
        byte[] data = new byte[prev.length + chunkData.length];
        System.arraycopy(prev, 0, data, 0, prev.length);
        System.arraycopy(chunkData, 0, data, prev.length, chunkData.length);
        if (data.length > dataLength) {
            data = Arrays.copyOfRange(data, 0, dataLength);
        }
        return new FrameAcc(data, dataLength, sequence + 1);
    }

    private static class InterfacePick {
        final UsbInterface usbInterface;
        final UsbEndpoint in;
        final UsbEndpoint out;

        InterfacePick(UsbInterface usbInterface, UsbEndpoint in, UsbEndpoint out) {
            this.usbInterface = usbInterface;
            this.in = in;
            this.out = out;
        }
    }

    /**
     * Prefer HID (class 3) — that is what Ledger uses — then vendor-specific (255),
     * then any interface with IN+OUT endpoints.
     */
    private InterfacePick pickInterface(UsbDevice device) {
        InterfacePick hid = pickOnClass(device, UsbConstants.USB_CLASS_HID); // 3
        if (hid != null) {
            return hid;
        }
        InterfacePick vendor = pickOnClass(device, 255);
        if (vendor != null) {
            return vendor;
        }
        for (int i = 0; i < device.getInterfaceCount(); i++) {
            InterfacePick p = pickOnInterface(device.getInterface(i));
            if (p != null) {
                return p;
            }
        }
        return null;
    }

    private InterfacePick pickOnClass(UsbDevice device, int interfaceClass) {
        for (int i = 0; i < device.getInterfaceCount(); i++) {
            UsbInterface iface = device.getInterface(i);
            if (iface.getInterfaceClass() == interfaceClass) {
                InterfacePick p = pickOnInterface(iface);
                if (p != null) {
                    return p;
                }
            }
        }
        return null;
    }

    private InterfacePick pickOnInterface(UsbInterface iface) {
        if (iface == null) {
            return null;
        }
        UsbEndpoint in = findEndpoint(iface, UsbConstants.USB_DIR_IN);
        UsbEndpoint out = findEndpoint(iface, UsbConstants.USB_DIR_OUT);
        if (in != null && out != null) {
            return new InterfacePick(iface, in, out);
        }
        return null;
    }

    /**
     * Prefer interrupt (HID), then bulk. Match original plugin preference for EP #3
     * when multiple candidates exist.
     */
    private UsbEndpoint findEndpoint(UsbInterface iface, int direction) {
        UsbEndpoint preferredEp3 = null;
        UsbEndpoint interrupt = null;
        UsbEndpoint bulk = null;
        UsbEndpoint any = null;

        for (int j = 0; j < iface.getEndpointCount(); j++) {
            UsbEndpoint ep = iface.getEndpoint(j);
            if (ep.getDirection() != direction) {
                continue;
            }
            if (any == null) {
                any = ep;
            }
            int type = ep.getType();
            if (ep.getEndpointNumber() == 3) {
                preferredEp3 = ep;
            }
            if (type == UsbConstants.USB_ENDPOINT_XFER_INT && interrupt == null) {
                interrupt = ep;
            }
            if (type == UsbConstants.USB_ENDPOINT_XFER_BULK && bulk == null) {
                bulk = ep;
            }
        }

        if (preferredEp3 != null) {
            return preferredEp3;
        }
        if (interrupt != null) {
            return interrupt;
        }
        if (bulk != null) {
            return bulk;
        }
        return any;
    }

    private String describeInterfaces(UsbDevice device) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < device.getInterfaceCount(); i++) {
            UsbInterface iface = device.getInterface(i);
            sb.append("[id=").append(iface.getId())
                    .append(" class=").append(iface.getInterfaceClass())
                    .append(" eps=");
            for (int j = 0; j < iface.getEndpointCount(); j++) {
                UsbEndpoint ep = iface.getEndpoint(j);
                sb.append(ep.getEndpointNumber())
                        .append(ep.getDirection() == UsbConstants.USB_DIR_IN ? "IN" : "OUT")
                        .append("t").append(ep.getType())
                        .append(",");
            }
            sb.append("]");
        }
        return sb.toString();
    }

    /** Debug snapshot for Dart logs. */
    public Map<String, Object> connectionInfo() {
        synchronized (lock) {
            Map<String, Object> map = new HashMap<>();
            map.put("connected", connection != null);
            map.put("singleton", true);
            map.put("thread", Thread.currentThread().getName());
            if (device != null) {
                map.put("deviceName", device.getDeviceName());
                map.put("vendorId", device.getVendorId());
                map.put("productId", device.getProductId());
                map.put("hasPermission", usbManager.hasPermission(device));
            }
            if (usbInterface != null) {
                map.put("interfaceId", usbInterface.getId());
                map.put("interfaceClass", usbInterface.getInterfaceClass());
            }
            if (usbEndpointReadIn != null) {
                map.put("inEp", usbEndpointReadIn.getEndpointNumber());
            }
            if (usbEndpointWriteOut != null) {
                map.put("outEp", usbEndpointWriteOut.getEndpointNumber());
            }
            return map;
        }
    }
}
