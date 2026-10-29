import AVFoundation
import Foundation
import ImageIO
import Vision

/// Recognising a book's ISBN in an EAN-13 barcode ("Bookland": 978 / 979 plus
/// a check digit). The check digit is verified so a misread frame from the
/// live camera is never mistaken for an ISBN.
enum ISBNBarcode {
    /// The ISBN-13 in a scanned barcode's text, or nil if it isn't one.
    static func isbn(fromPayload payload: String) -> String? {
        let digits = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard digits.count == 13, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        // 978 and 979 are books; 9790 is printed music (ISMN), not an ISBN.
        guard digits.hasPrefix("978") || (digits.hasPrefix("979") && !digits.hasPrefix("9790")) else { return nil }
        return hasValidCheckDigit(digits) ? digits : nil
    }

    /// EAN-13 / ISBN-13 check: digits weighted 1,3,1,3… sum to a multiple of 10.
    static func hasValidCheckDigit(_ digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard values.count == 13 else { return false }
        let sum = values.enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 1 : 3) }
        return sum % 10 == 0
    }
}

/// Finds ISBN barcodes in images and camera frames with Apple's Vision framework.
enum BarcodeReader {
    /// How a barcode that was read should be treated.
    enum Kind: Equatable {
        /// A book: the ISBN-13.
        case isbn(String)
        /// A real barcode that isn't a book (a product code, a QR code, a shelf label…).
        case other
        /// Probably a misread (an EAN-13 whose check digit doesn't add up), so say nothing.
        case ignore
    }

    /// What one image or camera frame contained.
    struct Scan: Equatable {
        var isbns: [String] = []
        /// Distinct payloads of barcodes that aren't ISBNs.
        var others: [String] = []
    }

    static func classify(_ payload: String?, symbology: VNBarcodeSymbology) -> Kind {
        guard let payload = payload?.trimmingCharacters(in: .whitespacesAndNewlines), !payload.isEmpty else {
            return .ignore
        }
        if let isbn = ISBNBarcode.isbn(fromPayload: payload) { return .isbn(isbn) }
        // A damaged read of an EAN-13 (which includes UPC-A) is easy to tell
        // from a real product code: its check digit fails.
        if symbology == .ean13 { return ISBNBarcode.hasValidCheckDigit(payload) ? .other : .ignore }
        return .other
    }

    private static func request() -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.ean13]
        return request
    }

    private static func isbns(from request: VNDetectBarcodesRequest) -> [String] {
        var seen = Set<String>()
        return (request.results ?? [])
            .compactMap { $0.payloadStringValue.flatMap(ISBNBarcode.isbn(fromPayload:)) }
            .filter { seen.insert($0).inserted }
    }

    /// Reads barcodes of every kind Vision supports (used by the live camera,
    /// which reports barcodes that aren't ISBNs too).
    private static func scan(handler: VNImageRequestHandler) -> Scan {
        let request = VNDetectBarcodesRequest()
        guard (try? handler.perform([request])) != nil else { return Scan() }
        var scan = Scan()
        for observation in request.results ?? [] {
            switch classify(observation.payloadStringValue, symbology: observation.symbology) {
            case .isbn(let isbn): if !scan.isbns.contains(isbn) { scan.isbns.append(isbn) }
            case .other:
                if let payload = observation.payloadStringValue, !scan.others.contains(payload) {
                    scan.others.append(payload)
                }
            case .ignore: break
            }
        }
        return scan
    }

    static func scan(in image: CGImage) -> Scan {
        scan(handler: VNImageRequestHandler(cgImage: image, options: [:]))
    }

    static func scan(in sampleBuffer: CMSampleBuffer) -> Scan {
        scan(handler: VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:]))
    }

    static func isbns(in image: CGImage, orientation: CGImagePropertyOrientation = .up) -> [String] {
        let request = request()
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        return isbns(from: request)
    }

    /// Every ISBN barcode in an image file (a photo or screenshot). Honors the
    /// photo's orientation, so pictures taken sideways on a phone still read.
    static func isbns(inImageAt url: URL) -> [String] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32
        let orientation = raw.flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up
        return isbns(in: image, orientation: orientation)
    }

    /// Every ISBN barcode in one video frame from the camera.
    static func isbns(in sampleBuffer: CMSampleBuffer) -> [String] {
        let request = request()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        return isbns(from: request)
    }
}
