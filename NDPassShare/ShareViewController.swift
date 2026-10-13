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
            guard let self else { return }
            if self.model.save() { self.extensionContext?.completeRequest(returningItems: nil) }
        }, cancel: { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }))
        host.overrideUserInterfaceStyle = .dark
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await collect() }
    }

    /// What was shared, kept as file data until it's read: decoding a camera photo at full
    /// size would take most of the memory a share sheet gets.
    private func collect() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        var images: [ShareModel.Source] = []
        var text: [String] = []
        var link: String?
        for p in providers {
            if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                guard images.count < ShareModel.maxTickets, let data = await loadData(p, UTType.image) else { continue }
                images.append(.photo(data))
            } else if p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                guard images.count < ShareModel.maxTickets, let data = await loadData(p, UTType.pdf), let doc = PDFDocument(data: data) else { continue }
                let pdfText = (0..<min(doc.pageCount, 3)).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n")
                if let page = doc.page(at: 0) {
                    let r = page.bounds(for: .mediaBox)
                    if r.width > 1, r.height > 1 {
                        let scale = 1600 / max(r.width, r.height)
                        images.append(.page(page.thumbnail(of: CGSize(width: r.width * scale, height: r.height * scale), for: .mediaBox), pdfText))
                        continue
                    }
                }
                text.append(pdfText)
            } else if p.hasItemConformingToTypeIdentifier(UTType.url.identifier), let u = await loadURL(p) {
                if u.isFileURL {
                    // A text or email file from Files; anything big (a video, an archive) isn't a ticket.
                    let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    if size > 0, size < 5_000_000, let d = try? Data(contentsOf: u, options: .mappedIfSafe), let s = String(data: d, encoding: .utf8) {
                        text.append(Self.stripEmail(s))
                    }
                } else { link = u.absoluteString }
            } else if p.hasItemConformingToTypeIdentifier("public.email-message"), let d = await loadData(p, UTType(importedAs: "public.email-message")),
                      d.count < 10_000_000, let s = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) {
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

    /// The readable part of an email: Subject and From, then every text part of the body,
    /// decoded (base64 or quoted-printable) and without HTML.
    static func stripEmail(_ raw: String) -> String {
        let crlf = raw.contains("\r\n")
        let nl = crlf ? "\r\n" : "\n"
        let split = raw.components(separatedBy: nl + nl)
        var keep: [String] = []
        if let head = split.first {
            for l in head.components(separatedBy: .newlines) where l.hasPrefix("Subject:") || l.hasPrefix("From:") { keep.append(l) }
        }
        // Walk the MIME parts: each is headers, a blank line, a body.
        var bodies: [String] = []
        var i = 1
        var headers = split.first ?? ""
        while i < split.count {
            let body = split[i]
            let h = headers.lowercased()
            if h.contains("content-transfer-encoding: base64") {
                let b64 = body.components(separatedBy: nl).prefix { !$0.hasPrefix("--") }.joined()
                if let d = Data(base64Encoded: b64, options: .ignoreUnknownCharacters), let t = String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) {
                    bodies.append(t)
                }
            } else if h.contains("quoted-printable") {
                bodies.append(quotedPrintable(body))
            } else {
                bodies.append(body)
            }
            // The next part's headers are the tail of this chunk after a boundary line.
            if let r = body.range(of: nl + "--", options: .backwards) {
                let tail = body[r.upperBound...]
                headers = tail.components(separatedBy: nl).dropFirst().joined(separator: nl)
            } else { headers = "" }
            i += 1
        }
        let text = bodies.joined(separator: "\n")
            .replacingOccurrences(of: "(?s)<(script|style)[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<(br|/p|/div|/li|/tr|/h[1-6])[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
        keep.append(text)
        return keep.joined(separator: "\n")
    }

    /// "=3D" → "=", soft line breaks joined.
    static func quotedPrintable(_ s: String) -> String {
        let joined = s.replacingOccurrences(of: "=\r?\n", with: "", options: .regularExpression)
        var bytes: [UInt8] = []
        var it = Array(joined.utf8)[...]
        while let c = it.popFirst() {
            if c == UInt8(ascii: "="), it.count >= 2, let v = UInt8(String(decoding: it.prefix(2), as: UTF8.self), radix: 16) {
                bytes.append(v); it = it.dropFirst(2)
            } else { bytes.append(c) }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

@MainActor
final class ShareModel: ObservableObject {
    enum State { case reading, ready, nothing }
    @Published var state: State = .reading
    @Published var passes: [Pass] = []
    @Published var status = "Reading the ticket…"
    private let importer = Importer()

    static let maxTickets = 5
    enum Source { case photo(Data), page(UIImage, String) }

    func read(images: [Source], text: String, link: String?) async {
        var out: [Pass] = []
        for (i, src) in images.prefix(Self.maxTickets).enumerated() {
            status = images.count > 1 ? "Reading ticket \(i + 1) of \(images.count)…" : "Reading the ticket…"
            // One at a time, decoded small, so only one photo is ever in memory.
            let p: Pass?
            switch src {
            case .photo(let data):
                guard let img = ImageKit.downsample(data) else { continue }
                p = await importer.make(img, sourceURL: link, prefetchedText: nil)
            case .page(let img, let extra):
                p = await importer.make(img, sourceURL: link, prefetchedText: extra)
            }
            if let p { out.append(p) }
        }
        if images.isEmpty, link != nil || !text.isEmpty {
            status = link != nil && text.isEmpty ? "Opening the link…" : "Reading the ticket…"
            if let p = await importer.make(text: text, image: nil, sourceURL: link) { out.append(p) }
        }
        passes = out
        state = out.isEmpty ? .nothing : .ready
    }

    /// Nil when the tickets couldn't be opened; the sheet says so rather than losing them.
    @Published var saveFailed = false

    func save() -> Bool {
        guard let container = Store.openContainer() else { saveFailed = true; return false }
        let ctx = container.mainContext
        for p in passes { importer.file(p, into: ctx) }
        Store.touch()
        return true
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
        .alert("Couldn't save to NDPass", isPresented: $model.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: { Text("Open NDPass once, then try sharing again.") }
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
                HStack(spacing: 18) {
                    DateField(text: $pass.date)
                    TimeField(text: $pass.time)
                }
                .font(Theme.sans(10, .medium)).foregroundStyle(Theme.muted)
                .padding(.horizontal, 16).padding(.vertical, 6)
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
