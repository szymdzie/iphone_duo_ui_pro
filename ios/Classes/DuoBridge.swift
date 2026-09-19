// DuoBridge.swift - the iPhone Duo bridge for Flutter (package: iphone_duo_ui_pro).
//
// Registration is automatic: Flutter's GeneratedPluginRegistrant registers this plugin, so an app
// only needs the dependency and a pod install. No app-side wiring is required.
//
// Build flag:
//  * Xcode 27.1+: add DUO_SDK_27_1 to SWIFT_ACTIVE_COMPILATION_CONDITIONS for this pod to enable
//    reserved regions, the vertical bar edge and the hinge (see README.md). Those call sites come
//    from Apple's iPhone Duo Tech Talk code and were verified against the iOS 27.1 SDK.
//
// Channels:
//  * EventChannel  "iphone_duo/environment" - environment state maps (DuoEnvironment.fromMap in Dart).
//  * MethodChannel "iphone_duo/methods"     - "snapshot" returns the last state, or nil.
//
// How it works: an invisible, non-interactive SwiftUI view is attached over the FlutterViewController.
// It reads size classes, the view size and - on 27.1 - reserved regions, toolbarVerticalEdge and the
// hinge, and pushes every change to Dart. iOS 27.1 enums travel as String(describing:) so the bridge
// does not depend on type names Apple has not shown yet.
//
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.

import Flutter
import SwiftUI
import UIKit

public final class DuoBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
    public static let eventChannelName = "iphone_duo/environment"
    public static let methodChannelName = "iphone_duo/methods"

    private weak var registrar: FlutterPluginRegistrar?
    private var eventSink: FlutterEventSink?
    private var probeController: UIViewController?
    private var lastPayload: [String: Any] = [:]
    private var attachAttempts = 0

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DuoBridge(registrar: registrar)
        let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
        let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "snapshot":
            attachProbeIfNeeded()
            result(lastPayload.isEmpty ? nil : lastPayload)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        attachProbeIfNeeded()
        if !lastPayload.isEmpty {
            events(lastPayload)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Probe

    private func attachProbeIfNeeded() {
        guard probeController == nil else { return }
        guard let host = registrar?.viewController, host.isViewLoaded else {
            // The Flutter view controller may not be attached to a scene yet - retry shortly.
            guard attachAttempts < 40 else { return }
            attachAttempts += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.attachProbeIfNeeded()
            }
            return
        }

        guard #available(iOS 17.0, *) else {
            publish(DuoPayload.uikitSnapshot(of: host), host: host)
            return
        }

        let probe = DuoProbeFactory.makeController { [weak self, weak host] payload in
            guard let self, let host else { return }
            self.publish(payload, host: host)
        }
        probe.view.backgroundColor = .clear
        probe.view.isUserInteractionEnabled = false
        probe.view.accessibilityElementsHidden = true
        probe.view.translatesAutoresizingMaskIntoConstraints = false

        host.addChild(probe)
        host.view.addSubview(probe.view)
        NSLayoutConstraint.activate([
            probe.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            probe.view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            probe.view.topAnchor.constraint(equalTo: host.view.topAnchor),
            probe.view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        probe.didMove(toParent: host)
        probeController = probe
    }

    private func publish(_ payload: [String: Any], host: UIViewController) {
        var merged = payload
        merged["platform"] = "ios"
        merged["displayScale"] = Double(host.traitCollection.displayScale)
        merged["uikitVerticalBarEdge"] = DuoPayload.uikitVerticalBarEdge(of: host)
        if NSDictionary(dictionary: merged).isEqual(to: lastPayload) {
            return
        }
        lastPayload = merged
        eventSink?(merged)
    }
}

// MARK: - Payload helpers

enum DuoPayload {
    static func sizeClass(_ value: UserInterfaceSizeClass?) -> String {
        switch value {
        case .compact?: return "compact"
        case .regular?: return "regular"
        default: return "unspecified"
        }
    }

    static func sizeClass(_ value: UIUserInterfaceSizeClass) -> String {
        switch value {
        case .compact: return "compact"
        case .regular: return "regular"
        default: return "unspecified"
        }
    }

    static func rect(_ rect: DuoRect, active: Bool) -> [String: Any] {
        ["x": Double(rect.x), "y": Double(rect.y), "width": Double(rect.width), "height": Double(rect.height), "active": active]
    }

    /// State without SwiftUI (iOS < 17): the size and UIKit size classes only.
    static func uikitSnapshot(of host: UIViewController) -> [String: Any] {
        [
            "sdk271": false,
            "width": Double(host.view.bounds.width),
            "height": Double(host.view.bounds.height),
            "horizontalSizeClass": sizeClass(host.traitCollection.horizontalSizeClass),
            "verticalSizeClass": sizeClass(host.traitCollection.verticalSizeClass),
            "toolbarVerticalEdge": "unavailable",
            "divisions": [[String: Any]](),
            "occlusions": [[String: Any]](),
        ]
    }

    static func uikitVerticalBarEdge(of host: UIViewController) -> String {
        #if DUO_SDK_27_1
        if #available(iOS 27.1, *) {
            // Verified against the iOS 27.1 SDK (compiled and observed on the simulator): trait from the "Raise the bar with iPhone Duo" Tech Talk (kept as text).
            return String(describing: host.traitCollection.verticalBarEdge)
        }
        #endif
        return "unavailable"
    }
}

struct DuoRect: Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    init(_ rect: CGRect) {
        x = rect.minX
        y = rect.minY
        width = rect.width
        height = rect.height
    }

    func isClose(to other: DuoRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}

@available(iOS 17.0, *)
enum DuoProbeFactory {
    static func makeController(onPayload: @escaping ([String: Any]) -> Void) -> UIViewController {
        #if DUO_SDK_27_1
        if #available(iOS 27.1, *) {
            return UIHostingController(rootView: DuoProbe271(onPayload: onPayload))
        }
        #endif
        return UIHostingController(rootView: DuoProbeBase(onPayload: onPayload))
    }
}

// MARK: - Probe: iOS 17+ (no iPhone Duo APIs)

@available(iOS 17.0, *)
struct DuoProbeBase: View {
    let onPayload: ([String: Any]) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var size: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.size, initial: true) { _, newSize in
                    size = newSize
                    publish(size: newSize)
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: horizontalSizeClass) { publish(size: size) }
        .onChange(of: verticalSizeClass) { publish(size: size) }
    }

    private func publish(size: CGSize) {
        onPayload([
            "sdk271": false,
            "width": Double(size.width),
            "height": Double(size.height),
            "horizontalSizeClass": DuoPayload.sizeClass(horizontalSizeClass),
            "verticalSizeClass": DuoPayload.sizeClass(verticalSizeClass),
            "toolbarVerticalEdge": "unavailable",
            "divisions": [[String: Any]](),
            "occlusions": [[String: Any]](),
        ])
    }
}

// MARK: - Probe: iOS 27.1 (reserved regions, toolbarVerticalEdge, hinge)

#if DUO_SDK_27_1
@available(iOS 27.1, *)
struct DuoRegionsSnapshot: Equatable, Sendable {
    var activeDivisions: [DuoRect] = []
    var allDivisions: [DuoRect] = []
    var activeOcclusions: [DuoRect] = []
}

@available(iOS 27.1, *)
struct DuoProbe271: View {
    let onPayload: ([String: Any]) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    // Verified against the iOS 27.1 SDK (compiled and observed on the simulator): environment value from the "Raise the bar with iPhone Duo" Tech Talk.
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge

    @State private var size: CGSize = .zero
    @State private var regions = DuoRegionsSnapshot()
    @State private var hasHinge = false
    @State private var hingeStatus = "none"
    @State private var hingeAngleDegrees: Double = 0

    var body: some View {
        GeometryReader { proxy in
            // Verified against the iOS 27.1 SDK (compiled and observed on the simulator): calls from the "Strike a pose with adaptive layouts on iPhone Duo" Tech Talk.
            let snapshot = DuoRegionsSnapshot(
                activeDivisions: proxy.reservedRegions(kind: .division).map { DuoRect($0.frame) },
                allDivisions: proxy.reservedRegions(kind: .division, options: .includeInactive).map { DuoRect($0.frame) },
                activeOcclusions: proxy.reservedRegions(kind: .occlusion).map { DuoRect($0.frame) }
            )
            Color.clear
                .onChange(of: proxy.size, initial: true) { _, newSize in
                    size = newSize
                    publish(size: newSize, regions: regions)
                }
                .onChange(of: snapshot, initial: true) { _, newRegions in
                    regions = newRegions
                    publish(size: size, regions: newRegions)
                }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        // Verified against the iOS 27.1 SDK (compiled and observed on the simulator): modifier from the "Leverage multiple displays and scenes on iPhone Duo" Tech Talk.
        .onHingeChange { _, context in
            if let hinge = context.hinge {
                hasHinge = true
                hingeStatus = String(describing: hinge.status)
                hingeAngleDegrees = hinge.angle.degrees
            } else {
                hasHinge = false
                hingeStatus = "none"
            }
            publish(size: size, regions: regions)
        }
        .onChange(of: horizontalSizeClass) { publish(size: size, regions: regions) }
        .onChange(of: verticalSizeClass) { publish(size: size, regions: regions) }
        .onChange(of: String(describing: toolbarVerticalEdge)) { publish(size: size, regions: regions) }
    }

    private func publish(size: CGSize, regions: DuoRegionsSnapshot) {
        var divisions: [[String: Any]] = regions.allDivisions.map { rect in
            DuoPayload.rect(rect, active: regions.activeDivisions.contains { $0.isClose(to: rect) })
        }
        for active in regions.activeDivisions where !regions.allDivisions.contains(where: { $0.isClose(to: active) }) {
            divisions.append(DuoPayload.rect(active, active: true))
        }
        var payload: [String: Any] = [
            "sdk271": true,
            "width": Double(size.width),
            "height": Double(size.height),
            "horizontalSizeClass": DuoPayload.sizeClass(horizontalSizeClass),
            "verticalSizeClass": DuoPayload.sizeClass(verticalSizeClass),
            "toolbarVerticalEdge": String(describing: toolbarVerticalEdge),
            "divisions": divisions,
            "occlusions": regions.activeOcclusions.map { DuoPayload.rect($0, active: true) },
        ]
        if hasHinge {
            payload["hinge"] = ["status": hingeStatus, "angleDegrees": hingeAngleDegrees]
        }
        onPayload(payload)
    }
}
#endif
