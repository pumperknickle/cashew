import CID
import Foundation

public protocol Fetcher {
    func fetch(rawCid: String) async throws -> Data
}
