import SwiftUI

struct TestFixtureView: View {
    @State private var email: String = "hello"
    @State private var featureEnabled: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            Text("Root Title")
                .accessibilityIdentifier("root-title")

            FixtureLabelView(text: "Fixture Label", identifier: "fixture-label")

            VStack(spacing: 8) {
                Button("Primary") {}
                    .accessibilityIdentifier("primary-button")

                Button("Secondary") {}
                    .accessibilityIdentifier("secondary-button")

                Button("Disabled") {}
                    .disabled(true)
                    .accessibilityIdentifier("disabled-button")
            }
            .accessibilityIdentifier("button-group")
            .accessibilityElement(children: .contain)

            HStack(spacing: 8) {
                Text("Left")
                    .accessibilityIdentifier("left-label")
                Button("Child") {}
                    .accessibilityIdentifier("child-button")
            }
            .accessibilityIdentifier("row-container")
            .accessibilityElement(children: .contain)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("email-field")

            Toggle("Feature Enabled", isOn: $featureEnabled)
                .disabled(true)
                .accessibilityIdentifier("feature-toggle")

            DisabledSwitchView(label: "Disabled Switch", identifier: "disabled-switch")
        }
        .disabled(true)
        .padding()
        .accessibilityIdentifier("root")
        .accessibilityElement(children: .contain)
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
