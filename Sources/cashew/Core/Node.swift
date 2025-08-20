import ArrayTrie
import Foundation
import Multicodec
import CollectionConcurrencyKit

public protocol Node: Codable, LosslessStringConvertible, Sendable {
    typealias PathSegment = String

    // traversal
    func get(property: PathSegment) -> Address?
    func properties() -> Set<PathSegment>
    
    // update
    func set(properties: [PathSegment: Address]) -> Self
    
    func resolve(paths: ArrayTrie<ResolutionStrategy>, fetcher: Fetcher) async throws -> Self
    func keepingOnlyLinks() -> Self
    func storeRecursively(storer: Storer) throws
    func transform(transforms: ArrayTrie<Transform>) throws -> Self?
}

public extension Node {
    init?(data: Data) {
       guard let decoded = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
       self = decoded
    }
    
    func toData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(keepingOnlyLinks())
    }
    
    init?(_ description: String) {
        guard let data = description.data(using: .utf8) else { return nil }
        guard let newNode = Self(data: data) else { return nil }
        self = newNode
    }
    
    var description: String {
        return String(decoding: toData()!, as: UTF8.self)
    }
    
    func getFullString() -> String {
        return String(decoding: toFullData()!, as: UTF8.self)
    }
    
    func toFullData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    func keepingOnlyLinks() -> Self {
        var newProperties = [String: Address]()
        for property in properties() {
            newProperties[property] = get(property: property)!.removingNode()
        }
        return set(properties: newProperties)
    }
}
