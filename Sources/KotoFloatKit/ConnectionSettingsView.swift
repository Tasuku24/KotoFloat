import SwiftUI

struct ConnectionSettingsView: View {
    @Bindable var model: ConnectionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(L10n.text("connection.server")) {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent(L10n.text("connection.endpoint")) {
                        TextField("http://127.0.0.1:1234/v1", text: $model.endpoint)
                    }
                    LabeledContent(L10n.text("connection.model")) {
                        TextField(L10n.text("connection.modelPlaceholder"), text: $model.modelName)
                        if !model.availableModels.isEmpty {
                            Menu(L10n.text("connection.chooseModel")) {
                                ForEach(model.availableModels, id: \.self) { name in
                                    Button(name) { model.modelName = name }
                                }
                            }.fixedSize()
                        }
                    }
                    LabeledContent(L10n.text("connection.token")) {
                        SecureField(L10n.text("connection.keepToken"), text: $model.tokenInput)
                            .disabled(model.removeSavedToken)
                    }
                    Toggle(L10n.text("connection.removeToken"), isOn: $model.removeSavedToken)
                    Toggle(L10n.text("connection.allowHTTP"), isOn: $model.allowHTTP)
                    Text(L10n.text("connection.httpHint")).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .textFieldStyle(.roundedBorder)
                .padding(8)
            }
            HStack {
                Button(L10n.text("connection.save")) { model.save() }.disabled(model.isBusy)
                Button(L10n.text("connection.check")) { model.checkConnection() }.disabled(model.isBusy)
                Button(L10n.text("connection.trial")) { model.tryTranslation() }.disabled(model.isBusy)
                if model.isBusy {
                    Button(L10n.text("translation.cancel")) { model.cancel() }
                }
            }.controlSize(.small)
            Text(statusText)
                .font(.callout).fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 36, alignment: .topLeading)
                .accessibilityIdentifier("connectionStatus")
            if !model.trialOutput.isEmpty {
                Text(L10n.text("connection.preview") + " " + model.trialOutput)
                    .font(.caption).lineLimit(2).textSelection(.enabled)
            }
            Text(L10n.text("connection.testHint")).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onDisappear { model.cancel() }
    }

    private var statusText: String {
        switch model.status {
        case .idle: L10n.text("connection.idle")
        case .saved: L10n.text("connection.saved")
        case .checking: L10n.text("connection.checking")
        case .connected(let count): String(format: L10n.text("connection.connected"), count)
        case .trialRunning: L10n.text("connection.trialRunning")
        case .trialComplete: L10n.text("connection.trialComplete")
        case .cancelled: L10n.text("translation.cancelled")
        case .failed(let error): L10n.text("translation.error.\(error.rawValue)")
        }
    }
}
