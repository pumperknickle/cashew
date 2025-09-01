@testable import cashew
import Foundation

class TestStoreFetcher: Storer, Fetcher, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    
    func store(rawCid: String, data: Data) {
        lock.withLock {
            storage[rawCid] = data
        }
    }
    
    func fetch(rawCid: String) async throws -> Data {
        let data = lock.withLock {
            storage[rawCid]
        }
        guard let data = data else { throw FetchError.notFound }
        return data
    }
    
    func storeRaw(rawCid: String, data: Data) {
        lock.withLock {
            storage[rawCid] = data
        }
    }
}

enum FetchError: Error {
    case notFound
}
