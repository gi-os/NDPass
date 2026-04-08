import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    private let previewImageView = UIImageView()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let containerView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        handleSharedItems()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        
        // Container card
        containerView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
        containerView.layer.cornerRadius = 20
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Image preview
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.layer.cornerRadius = 12
        previewImageView.clipsToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(previewImageView)
        
        // Spinner
        spinner.color = UIColor(red: 0.91, green: 0.65, blue: 0.23, alpha: 1) // amber
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        containerView.addSubview(spinner)
        
        // Status label
        statusLabel.text = "Adding to NDPass..."
        statusLabel.textColor = .white
        statusLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // Cancel button
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.setTitleColor(UIColor(white: 1, alpha: 0.5), for: .normal)
        cancelBtn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelBtn)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 260),
            containerView.heightAnchor.constraint(equalToConstant: 300),
            
            previewImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            previewImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 180),
            previewImageView.heightAnchor.constraint(equalToConstant: 160),
            
            spinner.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 16),
            spinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            cancelBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            cancelBtn.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        ])
    }
    
    @objc private func cancelTapped() {
        close()
    }
    
    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showError("No items received")
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                        guard error == nil else {
                            self?.showError("Failed to load image")
                            return
                        }
                        
                        var image: UIImage?
                        var imageData: Data?
                        
                        if let url = data as? URL {
                            if let d = try? Data(contentsOf: url), let img = UIImage(data: d) {
                                image = img
                                imageData = img.jpegData(compressionQuality: 0.7)
                            }
                        } else if let img = data as? UIImage {
                            image = img
                            imageData = img.jpegData(compressionQuality: 0.7)
                        } else if let rawData = data as? Data, let img = UIImage(data: rawData) {
                            image = img
                            imageData = img.jpegData(compressionQuality: 0.7)
                        }
                        
                        guard let finalData = imageData else {
                            self?.showError("Could not read image")
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self?.previewImageView.image = image
                            self?.statusLabel.text = "Saving ticket..."
                        }
                        
                        self?.saveToAppGroup(finalData)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.statusLabel.text = "Opening NDPass..."
                            self?.spinner.stopAnimating()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            self?.openMainApp()
                        }
                    }
                    return
                }
            }
        }
        showError("No image found")
    }
    
    private func saveToAppGroup(_ data: Data) {
        guard let defaults = UserDefaults(suiteName: "group.com.gios.ndpass") else { return }
        let base64 = data.base64EncodedString()
        defaults.set(base64, forKey: "sharedTicketBase64")
        defaults.set("1", forKey: "pendingShareFlag")
        defaults.synchronize()
    }
    
    private func showError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = msg
            self?.spinner.stopAnimating()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.close()
            }
        }
    }
    
    private func openMainApp() {
        // Just open the app — the scan tab checks for shared images on focus
        let url = URL(string: "ndpass://")!
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                app.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = r.next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.close()
        }
    }
    
    private func close() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
