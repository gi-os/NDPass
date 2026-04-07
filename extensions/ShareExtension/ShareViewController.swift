import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                        guard error == nil else {
                            self?.close()
                            return
                        }

                        var imageData: Data?

                        if let url = data as? URL {
                            imageData = try? Data(contentsOf: url)
                        } else if let image = data as? UIImage {
                            imageData = image.jpegData(compressionQuality: 0.7)
                        } else if let data = data as? Data {
                            imageData = data
                        }

                        if let imageData = imageData {
                            self?.saveImageToAppGroup(imageData)
                        }

                        self?.openMainApp()
                    }
                    return
                }
            }
        }

        close()
    }

    private func saveImageToAppGroup(_ data: Data) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass"
        ) else { return }

        let fileURL = containerURL.appendingPathComponent("shared_ticket.jpg")

        // Write the image
        try? data.write(to: fileURL)

        // Write a flag so the app knows to process it
        let flagURL = containerURL.appendingPathComponent("pending_share.flag")
        try? "1".write(to: flagURL, atomically: true, encoding: .utf8)
    }

    private func openMainApp() {
        // Open the main app via URL scheme
        let url = URL(string: "ndpass://scan/shared")!

        // Share extensions can't open URLs directly — use responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }

        // Small delay then close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.close()
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
