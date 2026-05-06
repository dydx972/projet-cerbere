import SwiftUI
import WebKit

struct DashboardView: View {
    @State private var logs: [LogAcces] = []
    @State private var alertes: [Alerte] = []
    @State private var detections: [Detection] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // KPIs
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        KPICard(title: "Acces aujourd'hui", value: "\(logs.count)", color: "58a6ff")
                        KPICard(title: "Alertes actives", value: "\(alertes.filter { !$0.isAcquittee }.count)", color: "f85149")
                        KPICard(title: "Acces refuses", value: "\(logs.filter { $0.type_evenement == "acces_refuse" || $0.type_evenement == "badge_inconnu" }.count)", color: "f0883e")
                        KPICard(title: "Detections PIR", value: "\(detections.count)", color: "3fb950")
                    }
                    .padding(.horizontal)

                    // Camera live
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle().fill(Color(hex: "3fb950")).frame(width: 8, height: 8)
                            Text("Camera Entree W13")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "f85149"))
                                .cornerRadius(4)
                        }
                        CameraStreamView()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                    .padding(12)
                    .background(Color(hex: "161b22"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "30363d")))
                    .padding(.horizontal)

                    // Derniers acces
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DERNIERS ACCES")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "8b949e"))

                        ForEach(logs.prefix(5)) { log in
                            LogRow(log: log)
                        }

                        if logs.isEmpty && !isLoading {
                            Text("Aucun acces enregistre")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color(hex: "484f58"))
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "161b22"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "30363d")))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(hex: "0d1117"))
            .navigationTitle("CERBERE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CERBERE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "58a6ff"))
                }
            }
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    func loadData() async {
        isLoading = true
        do {
            let logsResp: APIResponse<[LogAcces]> = try await APIService.shared.get("logs.php")
            logs = logsResp.data ?? []
        } catch { print("Logs error: \(error)") }
        do {
            let alertResp: APIResponse<[Alerte]> = try await APIService.shared.get("alertes.php")
            alertes = alertResp.data ?? []
        } catch { print("Alertes error: \(error)") }
        do {
            let detResp: APIResponse<[Detection]> = try await APIService.shared.get("detections.php")
            detections = detResp.data ?? []
        } catch { print("Detections error: \(error)") }
        isLoading = false
    }
}

struct KPICard: View {
    let title: String
    let value: String
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "8b949e"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: "161b22"))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "30363d")))
    }
}

struct CameraStreamView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        let html = """
        <html>
        <head><meta name="viewport" content="width=device-width, initial-scale=1.0"><style>
        * { margin:0; padding:0; background:#000; }
        img { width:100%; height:100vh; object-fit:contain; }
        </style></head>
        <body>
        <img src="http://192.168.1.138:8090/stream" onerror="setTimeout(()=>{this.src='http://192.168.1.138:8090/stream?t='+Date.now()},2000)" />
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
