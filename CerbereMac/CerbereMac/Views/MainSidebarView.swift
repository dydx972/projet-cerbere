import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case porte = "Porte"
    case journaux = "Journaux"
    case alertes = "Alertes"
    case utilisateurs = "Utilisateurs"
    case detections = "Detections PIR"
    case camera = "Camera"
    case raspberrypi = "Raspberry Pi"
    case autorisations = "Autorisations"
    case configuration = "Configuration"
    case audit = "Audit Trail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .porte: return "door.left.hand.open"
        case .journaux: return "list.bullet.rectangle"
        case .alertes: return "exclamationmark.triangle"
        case .utilisateurs: return "person.2"
        case .detections: return "sensor"
        case .camera: return "video"
        case .raspberrypi: return "cpu"
        case .autorisations: return "lock.shield"
        case .configuration: return "gearshape.2"
        case .audit: return "doc.text.magnifyingglass"
        }
    }
}

struct MainSidebarView: View {
    var onLogout: () -> Void
    @State private var selectedItem: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Principal") {
                    ForEach([SidebarItem.dashboard, .porte, .journaux, .alertes, .utilisateurs], id: \.id) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }

                Section("Supervision") {
                    ForEach([SidebarItem.detections, .camera, .raspberrypi], id: \.id) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }

                Section("Gestion") {
                    ForEach([SidebarItem.autorisations, .configuration, .audit], id: \.id) { item in
                        Label(item.rawValue, systemImage: item.icon)
                            .tag(item)
                    }
                }

                Section {
                    Button(action: onLogout) {
                        Label("Deconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Color(hex: "f85149"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard: DashboardView()
                case .porte: DoorControlView()
                case .journaux: LogsView()
                case .alertes: AlertesView()
                case .utilisateurs: UtilisateursView()
                case .detections: DetectionsView()
                case .camera: CameraFullView()
                case .raspberrypi: RaspberryPiView()
                case .autorisations: AutorisationsView()
                case .configuration: ConfigView()
                case .audit: AuditView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0d1117"))
        }
    }
}
