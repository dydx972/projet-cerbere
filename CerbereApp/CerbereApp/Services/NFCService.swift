import Foundation
import CoreNFC

class NFCService: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate, NFCTagReaderSessionDelegate {
    @Published var isScanning = false
    @Published var lastStatus = ""
    @Published var lastStatusColor = "8b949e"
    @Published var doorOpened = false

    var onDoorOpen: (() -> Void)?
    private var ndefSession: NFCNDEFReaderSession?
    private var tagSession: NFCTagReaderSession?
    private var duree: Int = 5

    // Le tag NFC place pres du lecteur doit contenir "CERBERE_DOOR" en NDEF
    // OU on detecte n'importe quel tag NFC (mode universel)
    var requireSpecificTag = false

    func startScanning(duree: Int = 5) {
        guard NFCNDEFReaderSession.readingAvailable else {
            lastStatus = "NFC non disponible sur cet appareil"
            lastStatusColor = "f85149"
            return
        }

        self.duree = duree
        isScanning = true
        lastStatus = "Approchez votre iPhone du lecteur..."
        lastStatusColor = "58a6ff"

        // Utilise NDEF session pour lire les tags
        ndefSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        ndefSession?.alertMessage = "Approchez votre iPhone du lecteur RFID pour ouvrir la porte"
        ndefSession?.begin()
    }

    func stopScanning() {
        ndefSession?.invalidate()
        tagSession?.invalidate()
        isScanning = false
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            if let nfcError = error as? NFCReaderError,
               nfcError.code == .readerSessionInvalidationErrorUserCanceled {
                self.lastStatus = "Scan annule"
                self.lastStatusColor = "8b949e"
            } else if let nfcError = error as? NFCReaderError,
                      nfcError.code == .readerSessionInvalidationErrorFirstNDEFTagRead {
                // Tag lu avec succes, traitement en cours
            } else {
                self.lastStatus = "Erreur NFC"
                self.lastStatusColor = "f85149"
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Tag NDEF detecte
        var tagValid = !requireSpecificTag

        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8),
                   payload.contains("CERBERE") {
                    tagValid = true
                }
            }
        }

        if tagValid {
            session.alertMessage = "Porte en cours d'ouverture..."
            DispatchQueue.main.async {
                self.ouvrirPorte()
            }
        } else {
            session.alertMessage = "Tag non reconnu"
            DispatchQueue.main.async {
                self.lastStatus = "Tag NFC non reconnu"
                self.lastStatusColor = "f85149"
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session active
    }

    // MARK: - NFCTagReaderSessionDelegate

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        // N'importe quel tag detecte = ouvrir la porte
        session.alertMessage = "Tag detecte ! Ouverture de la porte..."
        session.invalidate()
        DispatchQueue.main.async {
            self.ouvrirPorte()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // Session active
    }

    // MARK: - Ouverture porte

    private func ouvrirPorte() {
        lastStatus = "Ouverture en cours..."
        lastStatusColor = "58a6ff"

        Task {
            do {
                let result = try await APIService.shared.post("porte_ouvrir.php", body: [
                    "duree": duree
                ])

                await MainActor.run {
                    if result["success"] as? Bool == true {
                        self.doorOpened = true
                        self.lastStatus = "Porte ouverte pour \(self.duree)s"
                        self.lastStatusColor = "3fb950"
                        self.onDoorOpen?()

                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.duree)) {
                            self.doorOpened = false
                            self.lastStatus = "Porte verrouillee"
                            self.lastStatusColor = "8b949e"
                        }
                    } else {
                        self.lastStatus = result["error"] as? String ?? "Erreur"
                        self.lastStatusColor = "f85149"
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastStatus = "Erreur de connexion"
                    self.lastStatusColor = "f85149"
                }
            }
        }
    }
}
