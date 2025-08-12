@testable import cashew
import Foundation

class TestStoreFetcher: Storer, Fetcher {
    var storage: [String: Data] = [:]
    
    func store(rawCid: String, data: Data) {
        storage[rawCid] = data
    }
    
    func fetch(rawCid: String) async throws -> Data {
        guard let data = storage[rawCid] else { throw FetchError.notFound }
        return data
    }
}

enum FetchError: Error {
    case notFound
}
