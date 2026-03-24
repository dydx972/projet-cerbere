import SwiftUI

struct MainTabView: View {
    var onLogout: () -> Void

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Dashboard")
                }

            DoorControlView()
                .tabItem {
                    Image(systemName: "door.left.hand.open")
                    Text("Porte")
                }

            LogsView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Journaux")
                }

            AlertesView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Alertes")
                }

            UtilisateursView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Utilisateurs")
                }

            SettingsView(onLogout: onLogout)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Systeme")
                }
        }
        .tint(Color(hex: "58a6ff"))
    }
}
