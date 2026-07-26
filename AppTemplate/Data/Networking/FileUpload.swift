import Foundation

/// Emitted while a file upload is in flight. A stream rather than a single decoded value
/// because upload has fundamentally different semantics from `send` (progress over time,
/// not one request/response) — that's the one case where a second `APIClient` method is
/// justified instead of forcing everything through `send`.
enum UploadEvent: Sendable {
    case progress(Double)
    case completed(Data)
    case failed(AppError)
}

/// What to upload and how to describe it in the multipart body. Grouped into one type so
/// `upload(_:file:)` and its helpers take one parameter instead of four loose strings.
struct FileUploadDescriptor {
    let fileURL: URL
    let fieldName: String
    let fileName: String
    let mimeType: String
}

/// Builds a single-file `multipart/form-data` body. Extend for multiple fields/files if
/// your upload endpoint needs them; this covers the common single-file case.
enum MultipartFormData {
    static func body(file: FileUploadDescriptor, boundary: String) throws -> Data {
        guard let fileData = try? Data(contentsOf: file.fileURL) else {
            throw AppError.unknown("Could not read file at \(file.fileURL.path).")
        }
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n".utf8
        ))
        body.append(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

/// Bridges `URLSessionUploadTask`'s delegate-based progress callbacks into an
/// `AsyncStream<UploadEvent>`. `@unchecked Sendable` because `URLSessionTaskDelegate`
/// callbacks aren't actor-isolated; all mutable state here is only ever touched from
/// those callbacks, which URLSession serializes onto its delegate queue.
final class UploadProgressObserver: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncStream<UploadEvent>.Continuation
    private let certificateValidator: PinnedCertificateValidator?
    private var responseData = Data()

    init(
        continuation: AsyncStream<UploadEvent>.Continuation,
        certificateValidator: PinnedCertificateValidator? = nil
    ) {
        self.continuation = continuation
        self.certificateValidator = certificateValidator
    }

    /// Forwards to the same pinning validator the main session uses, so an upload — which
    /// necessarily runs on its own `URLSession` to get progress callbacks — doesn't
    /// silently skip certificate pinning while every other request enforces it.
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let certificateValidator else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        certificateValidator.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        continuation.yield(.progress(Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { continuation.finish() }

        if let error {
            continuation.yield(.failed(.network(.requestFailed(statusCode: -1, message: error.localizedDescription))))
            return
        }
        guard let http = task.response as? HTTPURLResponse else {
            continuation.yield(.failed(.network(.invalidResponse)))
            return
        }
        guard (200..<300).contains(http.statusCode) else {
            continuation.yield(.failed(.network(.requestFailed(statusCode: http.statusCode, message: nil))))
            return
        }
        continuation.yield(.completed(responseData))
    }
}
