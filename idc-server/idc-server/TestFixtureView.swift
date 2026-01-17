import SwiftUI

struct TestFixtureView: View {
    @State private var email: String = "hello"
    @State private var password: String = ""
    @State private var notes: String = ""
    @State private var featureEnabled: Bool = true
    @State private var notificationsEnabled: Bool = false
    @State private var tapCount: Int = 0
    @State private var modeSelection: Int = 0
    @State private var sliderValue: Double = 0.35
    @State private var stepperValue: Int = 2
    @State private var menuSelection: String = "Daily"
    @State private var wheelSelection: String = "Two"
    @State private var scheduledDate: Date = Date()
    @State private var accentColor: Color = .orange
    @State private var showAlert: Bool = false
    @State private var showDialog: Bool = false
    @State private var showSheet: Bool = false
    @State private var progressValue: Double = 0.42

    var body: some View {
        TabView {
            controlsTab
            inputsTab
            pickersTab
            listsTab
            feedbackTab
        }
        .tint(.mint)
    }

    private var controlsTab: some View {
        NavigationStack {
            ZStack {
                FixtureBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        FixtureHeader(
                            title: "Controls",
                            subtitle: "Tap, toggle, and selection states"
                        )

                        FixtureCard(title: "Tap Counter", subtitle: "Primary interaction") {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tap Count: \(tapCount)")
                                        .font(.system(.title2, design: .rounded).weight(.semibold))
                                        .accessibilityIdentifier("tap-count")
                                    Text("Tap the button to increment")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(tapCount == 0 ? "Ready" : "Active")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.mint.opacity(0.2))
                                    )
                            }

                            HStack(spacing: 12) {
                                Button("Tap Me") {
                                    tapCount += 1
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("tap-button")

                                Button("Reset Tap Count") {
                                    tapCount = 0
                                    notificationsEnabled = false
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("reset-button")
                            }
                        }

                        FixtureCard(title: "Buttons", subtitle: "Primary / secondary / disabled") {
                            VStack(spacing: 8) {
                                Button("Primary") {}
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("primary-button")

                                Button("Secondary") {}
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("secondary-button")

                                Button("Disabled") {}
                                    .buttonStyle(.bordered)
                                    .disabled(true)
                                    .accessibilityIdentifier("disabled-button")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("button-group")

                        FixtureCard(title: "Inline Row", subtitle: "HStack layout") {
                            HStack(spacing: 12) {
                                Text("Left")
                                    .font(.callout.weight(.medium))
                                    .accessibilityIdentifier("left-label")
                                Spacer()
                                Button("Child") {}
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("child-button")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("row-container")

                        FixtureCard(title: "Switches", subtitle: "Stateful toggles") {
                            Toggle("Feature Enabled", isOn: $featureEnabled)
                                .disabled(true)
                                .accessibilityIdentifier("feature-toggle")

                            Toggle("Notifications", isOn: $notificationsEnabled)
                                .accessibilityIdentifier("notifications-toggle")

                            Text("Notifications: \(notificationsEnabled ? "On" : "Off")")
                                .font(.callout.weight(.semibold))
                                .accessibilityIdentifier("notifications-state")

                            DisabledSwitchView(label: "Disabled Switch", identifier: "disabled-switch")
                        }

                        FixtureCard(title: "Selection", subtitle: "Segmented, slider, stepper") {
                            Picker("Mode", selection: $modeSelection) {
                                Text("Standard").tag(0)
                                Text("Focus").tag(1)
                            }
                            .pickerStyle(.segmented)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Intensity")
                                        .font(.callout.weight(.medium))
                                    Spacer()
                                    Text(String(format: "%.0f%%", sliderValue * 100))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $sliderValue)
                            }

                            Stepper("Count: \(stepperValue)", value: $stepperValue, in: 0 ... 10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("fixture-root")
                }
            }
            .navigationTitle("Controls")
        }
        .tabItem {
            Label("Controls", systemImage: "slider.horizontal.3")
        }
    }

    private var inputsTab: some View {
        NavigationStack {
            ZStack {
                FixtureBackground(variant: .inputs)
                ScrollView {
                    VStack(spacing: 16) {
                        FixtureHeader(
                            title: "Inputs",
                            subtitle: "Text entry and UIKit bridged label"
                        )

                        FixtureCard(title: "Contact", subtitle: "Editable fields") {
                            TextField("Email", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("email-field")

                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("password-field")
                        }

                        FixtureCard(title: "Notes", subtitle: "Multiline editor") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.85))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                                .accessibilityIdentifier("notes-editor")
                        }

                        FixtureCard(title: "UIKit Label", subtitle: "UIViewRepresentable") {
                            FixtureLabelView(text: "Fixture Label", identifier: "fixture-label")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Inputs")
        }
        .tabItem {
            Label("Inputs", systemImage: "rectangle.and.pencil.and.ellipsis")
        }
    }

    private var pickersTab: some View {
        NavigationStack {
            ZStack {
                FixtureBackground(variant: .pickers)
                ScrollView {
                    VStack(spacing: 16) {
                        FixtureHeader(
                            title: "Pickers",
                            subtitle: "Menu, wheel, date, and color"
                        )

                        FixtureCard(title: "Menu Picker", subtitle: "Frequency") {
                            Picker("Frequency", selection: $menuSelection) {
                                Text("Daily").tag("Daily")
                                Text("Weekly").tag("Weekly")
                                Text("Monthly").tag("Monthly")
                            }
                            .pickerStyle(.menu)
                        }

                        FixtureCard(title: "Wheel Picker", subtitle: "Levels") {
                            Picker("Level", selection: $wheelSelection) {
                                Text("One").tag("One")
                                Text("Two").tag("Two")
                                Text("Three").tag("Three")
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }

                        FixtureCard(title: "Date & Color", subtitle: "Scheduling") {
                            DatePicker("Schedule", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)

                            ColorPicker("Accent", selection: $accentColor, supportsOpacity: false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Pickers")
        }
        .tabItem {
            Label("Pickers", systemImage: "dial.medium")
        }
    }

    private var listsTab: some View {
        NavigationStack {
            List {
                Section("Highlights") {
                    Label("Pinned", systemImage: "pin")
                    Label("Recent", systemImage: "clock")
                    Label("Favorites", systemImage: "star")
                }

                Section("Items") {
                    NavigationLink("Detail A") {}
                    NavigationLink("Detail B") {}
                    NavigationLink("Detail C") {}
                }

                Section("Status") {
                    HStack {
                        Text("Sync")
                        Spacer()
                        Text("Active")
                            .foregroundStyle(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Lists")
        }
        .tabItem {
            Label("Lists", systemImage: "list.bullet.rectangle")
        }
    }

    private var feedbackTab: some View {
        NavigationStack {
            ZStack {
                FixtureBackground(variant: .feedback)
                ScrollView {
                    VStack(spacing: 16) {
                        FixtureHeader(
                            title: "Feedback",
                            subtitle: "Progress and system dialogs"
                        )

                        FixtureCard(title: "Progress", subtitle: "Determinate and indeterminate") {
                            ProgressView(value: progressValue)
                            ProgressView("Loading")
                        }

                        FixtureCard(title: "Dialogs", subtitle: "Alert, confirmation, sheet") {
                            HStack(spacing: 12) {
                                Button("Alert") {
                                    showAlert = true
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Confirm") {
                                    showDialog = true
                                }
                                .buttonStyle(.bordered)

                                Button("Sheet") {
                                    showSheet = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Feedback")
        }
        .tabItem {
            Label("Feedback", systemImage: "sparkles")
        }
        .alert("Fixture Alert", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This is a lightweight alert for testing.")
        }
        .confirmationDialog("Choose an option", isPresented: $showDialog, titleVisibility: .visible) {
            Button("Confirm") {}
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 16) {
                Text("Fixture Sheet")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Use this to validate modal presentation and dismissal.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close") { showSheet = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}

struct FixtureCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

struct FixtureHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 12)
    }
}

struct FixtureBackground: View {
    enum Variant {
        case controls
        case inputs
        case pickers
        case feedback
    }

    var variant: Variant = .controls

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 220, height: 220)
                .blur(radius: 1)
                .offset(x: 140, y: -160)

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 260, height: 140)
                .rotationEffect(.degrees(-12))
                .offset(x: -130, y: 220)
        }
    }

    private var gradientColors: [Color] {
        switch variant {
        case .controls:
            return [
                Color(red: 0.98, green: 0.95, blue: 0.92),
                Color(red: 0.90, green: 0.96, blue: 0.98)
            ]
        case .inputs:
            return [
                Color(red: 0.95, green: 0.95, blue: 0.99),
                Color(red: 0.90, green: 0.98, blue: 0.95)
            ]
        case .pickers:
            return [
                Color(red: 0.96, green: 0.92, blue: 0.99),
                Color(red: 0.92, green: 0.98, blue: 0.94)
            ]
        case .feedback:
            return [
                Color(red: 0.95, green: 0.98, blue: 0.93),
                Color(red: 0.92, green: 0.95, blue: 0.99)
            ]
        }
    }
}

struct FixtureLabelView: UIViewRepresentable {
    let text: String
    let identifier: String

    func makeUIView(context _: Context) -> UILabel {
        let label = UILabel()
        label.text = text
        label.isAccessibilityElement = true
        label.accessibilityLabel = text
        label.accessibilityIdentifier = identifier
        return label
    }

    func updateUIView(_ uiView: UILabel, context _: Context) {
        uiView.text = text
        uiView.accessibilityLabel = text
        uiView.accessibilityIdentifier = identifier
    }
}

struct DisabledSwitchView: UIViewRepresentable {
    let label: String
    let identifier: String

    func makeUIView(context _: Context) -> UISwitch {
        let control = UISwitch()
        control.isOn = false
        control.isEnabled = false
        control.isAccessibilityElement = true
        control.accessibilityLabel = label
        control.accessibilityIdentifier = identifier
        return control
    }

    func updateUIView(_ uiView: UISwitch, context _: Context) {
        uiView.isEnabled = false
        uiView.accessibilityLabel = label
        uiView.accessibilityIdentifier = identifier
    }
}

#Preview {
    TestFixtureView()
}
