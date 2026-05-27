import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Custom Transferable for the bundle id of an app that the user
/// is dragging from a switcher cell onto a group chip / folder.
///
/// We pin the UTI explicitly to `.utf8PlainText` on both export and
/// import. SwiftUI's auto-derived String Transferable picks an
/// implementation-defined UTI that doesn't always match the receiver
/// side; with a hand-rolled `DataRepresentation` source and sink can't
/// disagree.
struct DraggedAppRef: Codable, Transferable {
    let bundleIdentifier: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .utf8PlainText) { ref in
            ref.bundleIdentifier.data(using: .utf8) ?? Data()
        } importing: { data in
            DraggedAppRef(bundleIdentifier: String(data: data, encoding: .utf8) ?? "")
        }
    }
}
