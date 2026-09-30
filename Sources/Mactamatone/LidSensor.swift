import Foundation
import IOKit.hid

/// Reads the MacBook's continuous lid-angle sensor. HID calls can block, so they
/// stay on a private queue; UI updates return to the main queue.
final class LidSensor {
    var onAngle: ((Double) -> Void)?
    var onStatus: ((Bool, SensorStatus) -> Void)?

    private let queue = DispatchQueue(label: "app.mactamatone.lid", qos: .userInitiated)
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: DispatchSourceTimer?
    private var failures = 0

    func start() {
        queue.async { [weak self] in self?.connect() }
    }

    func stop() {
        queue.async { [weak self] in self?.disconnect() }
    }

    private func publish(_ connected: Bool, _ status: SensorStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?(connected, status)
        }
    }

    private func connect() {
        guard device == nil else { return }
        let newManager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            kIOHIDDeviceUsagePageKey as String: 0x20,
            kIOHIDDeviceUsageKey as String: 0x8A
        ]
        IOHIDManagerSetDeviceMatching(newManager, matching as CFDictionary)
        let openResult = IOHIDManagerOpen(newManager, 0)
        guard openResult == kIOReturnSuccess else {
            publish(false, .accessFailed(String(format: "0x%08X", openResult)))
            return
        }
        manager = newManager

        let matches = IOHIDManagerCopyDevices(newManager) as? Set<IOHIDDevice> ?? []
        for candidate in matches {
            let product = (IOHIDDeviceGetProperty(candidate, kIOHIDProductKey as CFString) as? String)?.lowercased() ?? ""
            let page = (IOHIDDeviceGetProperty(candidate, kIOHIDPrimaryUsagePageKey as CFString) as? Int) ?? 0
            let usage = (IOHIDDeviceGetProperty(candidate, kIOHIDPrimaryUsageKey as CFString) as? Int) ?? 0
            // Matching by product name can return other HID devices on some
            // macOS versions. Never open a keyboard or pointer device.
            guard product == "las" || (page == 0x20 && usage == 0x8A) else { continue }
            guard IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess else { continue }
            if let angle = readAngle(from: candidate) {
                device = candidate
                publish(true, .connected)
                send(angle)
                startPolling()
                return
            }
            IOHIDDeviceClose(candidate, 0)
        }
        publish(false, .unavailable)
        disconnect()
    }

    private func startPolling() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(3))
        source.setEventHandler { [weak self] in self?.poll() }
        timer = source
        source.resume()
    }

    private func poll() {
        guard let device else { return }
        guard let angle = readAngle(from: device) else {
            failures += 1
            if failures == 30 {
                publish(false, .disconnected)
            }
            return
        }
        if failures >= 30 { publish(true, .reconnected) }
        failures = 0
        send(angle)
    }

    private func send(_ angle: Double) {
        DispatchQueue.main.async { [weak self] in self?.onAngle?(angle) }
    }

    private func readAngle(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        let raw = UInt16(report[2]) << 8 | UInt16(report[1])
        let angle = Double(raw)
        return (0...180).contains(angle) ? angle : nil
    }

    private func disconnect() {
        timer?.cancel()
        timer = nil
        if let device { IOHIDDeviceClose(device, 0) }
        device = nil
        if let manager { IOHIDManagerClose(manager, 0) }
        manager = nil
    }
}
