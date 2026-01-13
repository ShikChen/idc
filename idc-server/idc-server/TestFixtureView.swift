import SwiftUI

struct TestFixtureView: View {
    @State private var email: String = "hello"
    @State private var featureEnabled: Bool = true
    @State private var notificationsEnabled: Bool = false
    @State private var tapCount: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Root Title")
                .accessibilityIdentifier("root-title")

            FixtureLabelView(text: "Fixture Label", identifier: "fixture-label")

            Text("Tap Count: \(tapCount)")
                .accessibilityIdentifier("tap-count")

            Button("Tap Me") {
                tapCount += 1
            }
            .accessibilityIdentifier("tap-button")

            Button("Reset Tap Count") {
                tapCount = 0
                notificationsEnabled = false
            }
            .accessibilityIdentifier("reset-button")

            VStack(spacing: 8) {
                Button("Primary") {}
                    .accessibilityIdentifier("primary-button")

                Button("Secondary") {}
                    .accessibilityIdentifier("secondary-button")

                Button("Disabled") {}
                    .disabled(true)
                    .accessibilityIdentifier("disabled-button")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("button-group")

            HStack(spacing: 8) {
                Text("Left")
                    .accessibilityIdentifier("left-label")
                Button("Child") {}
                    .accessibilityIdentifier("child-button")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("row-container")

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("email-field")

            Toggle("Feature Enabled", isOn: $featureEnabled)
                .disabled(true)
                .accessibilityIdentifier("feature-toggle")

            Text("Notifications: \(notificationsEnabled ? "On" : "Off")")
                .accessibilityIdentifier("notifications-state")

            Toggle("Notifications", isOn: $notificationsEnabled)
                .accessibilityIdentifier("notifications-toggle")

            DisabledSwitchView(label: "Disabled Switch", identifier: "disabled-switch")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root")
    }
}

struct FixtureLabelView: UIViewRepresentable {
    let text: String
    let identifier: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = text
        label.isAccessibilityElement = true
        label.accessibilityLabel = text
        label.accessibilityIdentifier = identifier
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.accessibilityLabel = text
        uiView.accessibilityIdentifier = identifier
    }
}

struct DisabledSwitchView: UIViewRepresentable {
    let label: String
    let identifier: String

    func makeUIView(context: Context) -> UISwitch {
        let control = UISwitch()
        control.isOn = false
        control.isEnabled = false
        control.isAccessibilityElement = true
        control.accessibilityLabel = label
        control.accessibilityIdentifier = identifier
        return control
    }

    func updateUIView(_ uiView: UISwitch, context: Context) {
        uiView.isEnabled = false
        uiView.accessibilityLabel = label
        uiView.accessibilityIdentifier = identifier
    }
}

#Preview {
    TestFixtureView()
}
