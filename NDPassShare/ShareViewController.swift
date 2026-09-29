import UIKit
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import UserNotifications
import SwiftData

/// "Share to NDPass" from Photos, Safari, Mail, Files or any app: screenshots, photos, PDFs,
/// links, text and emails. The sheet reads the ticket right here, on this iPhone, shows it
/// with its fields to fix, and Add files it into NDPass. No need to open the app.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareCard(model: model, add: { [weak self] in
            self?.model.save()
            self?.extensionContext?.completeRequest(returningItems: nil)
        }, cancel: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await collect() }
    }

    private func collect() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var images: [(UIImage, String?)] = []
        var text: [String] = []
        var link: String?
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.image.identifier), let data = await loadData(p, UTType.image), let img = UIImage(data: data) {
                images.append((img, nil))
            } else if p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier), let data = await loadData(p, UTType.pdf),
                      let doc = PDFDocument(data: data) {
                let pdfText = (0..<min(doc.pageCount, 3)).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
                if let page = doc.page(at: 0) {
                    let r = page.bounds(for: .mediaBox)
                    let scale = 1600 / max(r.width, r.height)
                    images.append((page.thumbnail(of: CGSize(width: r.width * scale, height: r.height * scale), for: .mediaBox), pdfText))
                } else { text.append(pdfText) }
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
        await model.read(images: images, text: text.joined(separator: "\n"), link: link)
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

@MainActor
final class ShareModel: ObservableObject {
    enum State { case reading, ready, nothing }
    @Published var state: State = .reading
    @Published var passes: [Pass] = []
    @Published var status = "Reading the ticket…"
    private let importer = Importer()
    private lazy var container = Store.container()

    func read(images: [(UIImage, String?)], text: String, link: String?) async {
        var out: [Pass] = []
        for (i, (img, extra)) in images.prefix(5).enumerated() {
            status = images.count > 1 ? "Reading ticket \(i + 1) of \(min(images.count, 5))…" : "Reading the ticket…"
            if let p = await importer.make(img, sourceURL: link, prefetchedText: extra) { out.append(p) }
        }
        if images.isEmpty, link != nil || !text.isEmpty {
            status = link != nil && text.isEmpty ? "Opening the link…" : "Reading the ticket…"
            if let p = await importer.make(text: text, image: nil, sourceURL: link) { out.append(p) }
        }
        passes = out
        state = out.isEmpty ? .nothing : .ready
    }

    func save() {
        let ctx = container.mainContext
        for p in passes { importer.file(p, into: ctx) }
        Store.touch()
    }
}

struct ShareCard: View {
    @ObservedObject var model: ShareModel
    var add: () -> Void
    var cancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .reading:
                    VStack(spacing: 14) {
                        ProgressView().tint(Theme.accent).controlSize(.large)
                        Text(model.status).font(Theme.sans(16, .medium)).foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .nothing:
                    VStack(spacing: 8) {
                        Image(systemName: "ticket").font(.system(size: 40)).foregroundStyle(Theme.accent)
                        Text("No ticket found").font(Theme.serif(30)).foregroundStyle(Theme.ink)
                        Text("Share a screenshot, photo, PDF, link or email of a ticket.")
                            .font(Theme.sans(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                    .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready:
                    ScrollView {
                        VStack(spacing: 22) {
                            ForEach(model.passes, id: \.id) { p in ShareTicket(pass: p) }
                        }
                        .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 110)
                    }
                    .safeAreaInset(edge: .bottom) {
                        Button(action: add) {
                            Text(model.passes.count > 1 ? "Add \(model.passes.count) tickets" : "Add to NDPass")
                                .font(Theme.sans(17, .semibold)).foregroundStyle(Theme.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 54).background(Theme.accent, in: Capsule())
                        }
                        .padding(.horizontal, 18).padding(.bottom, 10)
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Add ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel).tint(Theme.ink) }
                if model.state == .ready {
                    ToolbarItem(placement: .confirmationAction) { Button("Add", action: add).tint(Theme.accent).fontWeight(.semibold) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// One read ticket: the cover it'll get in NDPass, then its fields to check and fix.
struct ShareTicket: View {
    @Bindable var pass: Pass

    var body: some View {
        VStack(spacing: 0) {
            TicketArt(pass: pass, logoHeight: 56).frame(height: 170)
            VStack(spacing: 0) {
                field("Title", $pass.title)
                field("Venue", $pass.venue)
                HStack(spacing: 0) {
                    field("Date", $pass.date, placeholder: "yyyy-mm-dd")
                    field("Time", $pass.time, placeholder: "7:30 PM")
                }
                field("Seat", $pass.seat, mono: true)
            }
            .padding(.vertical, 6)
            .background(Theme.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func field(_ label: String, _ text: Binding<String>, placeholder: String = "", mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(Theme.sans(10, .medium)).tracking(1).foregroundStyle(Theme.muted)
            TextField(placeholder, text: text)
                .font(mono ? Theme.mono(16) : Theme.sans(16)).foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.words).autocorrectionDisabled(mono)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
