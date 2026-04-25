import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AdaptiveNavigation<PrimaryView, SecondaryView, Enum>: View where PrimaryView: View, SecondaryView: View, Enum: Identifiable & Hashable {
#if os(macOS)
    let sizeClass = UserInterfaceSizeClass.compact
#else
    @Environment(\.horizontalSizeClass) var sizeClass
#endif
    @ViewBuilder var primaryColumn: PrimaryView
    @ViewBuilder var secondaryColumn: SecondaryView
    @Binding var showNav: Enum?

    init(_ primary: PrimaryView, _ secondary: SecondaryView, showNav: Binding<Enum?>) {
        primaryColumn = primary
        secondaryColumn = secondary
        _showNav = showNav
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    primaryColumn
                        .frame(maxWidth: columnMaxWidth)
                    ZStack(alignment: .topLeading) {
                        secondaryColumn
#if os(iOS)
                        KeyboardDismissOverlay()
                            .allowsHitTesting(true)
#endif
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                primaryColumn
            }
        }
        .adaptiveNavigationDestination(item: (sizeClass == .compact ? $showNav : .constant(nil)), destination: { secondaryColumn })
    }
}

extension View {
    func adaptiveNavigationDestination<Enum: Identifiable & Hashable, Destination: View>(
        item: Binding<Enum?>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        if #available(iOS 18.0, macOS 14.0, *) {
            return self.navigationDestination(item: item) { _ in
                destination()
            }
        } else {
            return self.sheet(item: item) { _ in
                NavigationStack {
                    destination()
                        .adaptiveNavigationBarTitleInline()
                }
            }
        }
    }
}

#if os(iOS)
struct KeyboardDismissOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let overlayView = gestureRecognizer.view,
                  let window = overlayView.window else { return false }

            let locationInOverlay = touch.location(in: overlayView)
            let locationInWindow = overlayView.convert(locationInOverlay, to: window)

            // Temporarily disable the overlay so hitTest can see through it
            let wasEnabled = overlayView.isUserInteractionEnabled
            overlayView.isUserInteractionEnabled = false
            let hitView = window.hitTest(locationInWindow, with: nil)
            overlayView.isUserInteractionEnabled = wasEnabled

            if let hitView = hitView {
                var current: UIView? = hitView
                while let v = current {
                    if v is UITextField || v is UITextView {
                        return false
                    }
                    current = v.superview
                }
            }

            return true
        }
    }
}
#endif
