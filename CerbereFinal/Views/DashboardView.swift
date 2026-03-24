import SwiftUI

struct DashboardView: View {
    @ObservedObject var service: DataService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Vue d'ensemble").font(.largeTitle).bold().padding(.horizontal)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    KPICard(title: "Utilisateurs", value: "\(service.stats.totalUsers)", color: .blue)
                    KPICard(title: "Badges", value: "\(service.stats.activeBadges)", color: .green)
                }.padding(.horizontal)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Activité récente").font(.headline).padding(.horizontal)
                    ForEach(service.logs) { log in LogEntryRow(log: log) }
                }
            }.padding(.vertical)
        }.background(Color(red: 0.03, green: 0.05, blue: 0.07).ignoresSafeArea())
    }
}

struct KPICard: View {
    var title: String; var value: String; var color: Color
    var body: some View {
        VStack(alignment: .leading) {
            Text(title.uppercased()).font(.caption).foregroundColor(.gray)
            Text(value).font(.largeTitle).bold().foregroundColor(color)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.05)).cornerRadius(10)
    }
}

struct LogEntryRow: View {
    var log: Log
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(log.ts.suffix(8)).font(.caption).foregroundColor(.gray)
                Text("\(log.user ?? "Inconnu") — \(log.porte)").foregroundColor(.white)
            }
            Spacer()
            Text(log.event.uppercased()).font(.caption).padding(4).background(log.event.contains("accorde") ? Color.green.opacity(0.2) : Color.red.opacity(0.2)).foregroundColor(log.event.contains("accorde") ? .green : .red).cornerRadius(4)
        }.padding().background(Color.white.opacity(0.05)).cornerRadius(8).padding(.horizontal)
    }
}
