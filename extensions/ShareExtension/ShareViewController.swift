import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close(); return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                        guard error == nil else { self?.close(); return }

                        var imageData: Data?
                        if let url = data as? URL {
                            imageData = try? Data(contentsOf: url)
                        } else if let image = data as? UIImage {
                            imageData = image.jpegData(compressionQuality: 0.7)
                        } else if let rawData = data as? Data {
                            // Try to make a UIImage to re-encode as JPEG
                            if let img = UIImage(data: rawData) {
                                imageData = img.jpegData(compressionQuality: 0.7)
                            } else {
                                imageData = rawData
                            }
                        }

                        if let imageData = imageData {
                            self?.saveToAppGroup(imageData)
                        }
                        
                        DispatchQueue.main.async {
                            self?.openMainApp()
                        }
                    }
                    return
                }
            }
        }
        close()
    }

    private func saveToAppGroup(_ data: Data) {
        guard let defaults = UserDefaults(suiteName: "group.com.gios.ndpass") else { return }
        
        // Save as base64 string so RN SharedStorage native module can read it
        let base64 = data.base64EncodedString()
        defaults.set(base64, forKey: "sharedTicketBase64")
        defaults.set("1", forKey: "pendingShareFlag")
        defaults.synchronize()
        
        // Also save as file for backup
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass"
        ) {
            let fileURL = containerURL.appendingPathComponent("shared_ticket.jpg")
            try? data.write(to: fileURL)
        }
    }

    private func openMainApp() {
        let url = URL(string: "ndpass://scan/shared")!
        
        // Share extensions can't call UIApplication.open directly
        // Use the openURL selector on the extension context's host app
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = r.next
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
