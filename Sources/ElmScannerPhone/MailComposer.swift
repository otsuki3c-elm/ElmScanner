import MessageUI
import SwiftUI

/// A file to attach to an email.
struct MailAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
    let mimeType: String
    let subject: String
}

/// The system email composer with one attachment. `onFinish` gets the result
/// once the composer closes (`.sent` means the message went out).
struct MailComposer: UIViewControllerRepresentable {
    let attachment: MailAttachment
    let onFinish: (MFMailComposeResult) -> Void

    /// False when no mail account is set up on the iPhone.
    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(attachment.subject)
        composer.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) { self.onFinish(result) }
        }
    }
}
