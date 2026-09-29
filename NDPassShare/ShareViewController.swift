import UIKit
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import UserNotifications

/// "Share to NDPass" from Photos, Safari, Mail, Files or any app: screenshots, photos, PDFs,
/// links, text and emails. The item is handed to the app, which reads it on-device the next
/// time it opens; a notification takes you there.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareCard(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await collect() }
    }

    private func collect() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var saved = 0
        var text: [String] = []
        var link: String?
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.image.identifier), let data = await loadData(p, UTType.image) {
                let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.9) ?? data
                if (try? Inbox.write(InboxItem(url: link, hasImage: true), image: jpeg)) != nil { saved += 1 }
            } else if p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier), let data = await loadData(p, UTType.pdf),
                      let doc = PDFDocument(data: data) {
                let pdfText = (0..<min(doc.pageCount, 3)).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
                let img = doc.page(at: 0).map { page -> Data? in
                    let r = page.bounds(for: .mediaBox)
                    let scale = 1600 / max(r.width, r.height)
                    return page.thumbnail(of: CGSize(width: r.width * scale, height: r.height * scale), for: .mediaBox).jpegData(compressionQuality: 0.9)
                } ?? nil
                if (try? Inbox.write(InboxItem(text: pdfText, url: link, hasImage: img != nil), image: img)) != nil { saved += 1 }
            } else if p.hasItemConformingToTypeIdentifier(UTType.url.identifier), let u = await loadURL(p) {
                if u.isFileURL, let d = try? Data(contentsOf: u), let s = String(data: d, encoding: .utf8) { text.append(Self.stripEmail(s)) }
                else { link = u.absoluteString }
            } else if p.hasItemConformingToTypeIdentifier("public.email-message"), let d = await loadData(p, UTType(importedAs: "public.email-message")),
                      let s = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) {
                text.append(Self.stripEmail(s))
            } else if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier), let s = await loadText(p) {
                text.append(s)
            }
        }
        // A link or text with no picture becomes one item the app reads as text.
        if saved == 0, link != nil || !text.isEmpty {
            if (try? Inbox.write(InboxItem(text: text.joined(separator: "\n"), url: link), image: nil)) != nil { saved += 1 }
        }
        if saved > 0 { await notify(saved) }
        await MainActor.run { model.state = saved > 0 ? .saved(saved) : .nothing }
    }

    private func notify(_ n: Int) async {
        let c = UNMutableNotificationContent()
        c.title = n == 1 ? "Ticket ready in NDPass" : "\(n) tickets ready in NDPass"
        c.body = "Tap to read and file it."
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "share-\(UUID())", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    private func loadData(_ p: NSItemProvider, _ type: UTType) async -> Data? {
        await withCheckedContinuation { cont in
            p.loadDataRepresentation(forTypeIdentifier: type.identifier) { d, _ in cont.resume(returning: d) }
        }
    }

    private func loadURL(_ p: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = p.loadObject(ofClass: URL.self) { u, _ in cont.resume(returning: u) }
        }
    }

    private func loadText(_ p: NSItemProvider) async -> String? {
        await withCheckedContinuation { cont in
            _ = p.loadObject(ofClass: String.self) { s, _ in cont.resume(returning: s) }
        }
    }

    /// The readable part of an email: headers that matter, then the body without HTML.
    static func stripEmail(_ raw: String) -> String {
        var keep: [String] = []
        let parts = raw.components(separatedBy: "\r\n\r\n").count > 1 ? raw.components(separatedBy: "\r\n\r\n") : raw.components(separatedBy: "\n\n")
        if let head = parts.first {
            for l in head.components(separatedBy: .newlines) where l.hasPrefix("Subject:") || l.hasPrefix("From:") { keep.append(l) }
        }
        let body = parts.dropFirst().joined(separator: "\n")
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "=\r?\n", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
        keep.append(body)
        return keep.joined(separator: "\n")
    }
}

final class ShareModel: ObservableObject {
    enum State: Equatable { case working, saved(Int), nothing }
    @Published var state: State = .working
}

struct ShareCard: View {
    @ObservedObject var model: ShareModel
    var done: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            switch model.state {
            case .working:
                ProgressView().tint(Color(red: 0.94, green: 0.54, blue: 0.24))
                Text("Adding to NDPass…").font(.headline)
            case .saved(let n):
                Image(systemName: "ticket").font(.system(size: 44)).foregroundStyle(Color(red: 0.94, green: 0.54, blue: 0.24))
                Text(n == 1 ? "Sent to NDPass" : "\(n) sent to NDPass").font(.title2.bold())
                Text("Open NDPass and it reads and files it for you.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            case .nothing:
                Text("Nothing NDPass can read here.").font(.headline)
                Text("Share a screenshot, photo, PDF, link or email of a ticket.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: done) {
                Text("Done").font(.headline).foregroundStyle(Color(red: 0.11, green: 0.05, blue: 0.02))
                    .frame(maxWidth: .infinity, minHeight: 50).background(Color(red: 0.94, green: 0.54, blue: 0.24), in: Capsule())
            }
        }
        .padding(28)
        .foregroundStyle(Color(red: 0.96, green: 0.91, blue: 0.85))
        .background(Color(red: 0.08, green: 0.04, blue: 0.02).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
