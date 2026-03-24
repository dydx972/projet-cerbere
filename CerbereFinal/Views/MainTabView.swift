import SwiftUI

struct MainTabView: View {
    @ObservedObject var service: DataService
    var body: some View {
        TabView {
            DashboardView(service: service).tabItem { Label("Tableau", systemImage: "square.grid.2x2.fill") }
            UsersView(service: service).tabItem { Label("Utilisateurs", systemImage: "person.3.fill") }
            LogsView(service: service).tabItem { Label("Logs", systemImage: "list.bullet.rectangle.portrait.fill") }
            DoorsView(service: service).tabItem { Label("Portes", systemImage: "lock.fill") }
        }.accentColor(.cyan)
    }
}

struct UsersView: View {
    @ObservedObject var service: DataService
    var body: some View {
        NavigationView {
            List(service.users) { user in
                VStack(alignment: .leading) {
                    Text("\(user.nom) \(user.prenom)").bold()
                    Text(user.role).font(.caption).foregroundColor(.gray)
                }
            }.navigationTitle("Utilisateurs")
        }
    }
}

struct LogsView: View {
    @ObservedObject var service: DataService
    var body: some View {
        NavigationView {
            List(service.logs) { log in LogEntryRow(log: log) }.navigationTitle("Logs")
        }
    }
}

struct DoorsView: View {
    @ObservedObject var service: DataService
    var body: some View {
        NavigationView {
            List(service.doors) { door in
                HStack {
                    Text(door.nom)
                    Spacer()
                    Text(door.etat.uppercased()).foregroundColor(door.etat == "verrouille" ? .blue : .green)
                }
            }.navigationTitle("Portes")
        }
    }
}
