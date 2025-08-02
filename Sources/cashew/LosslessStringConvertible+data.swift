import Foundation

public extension LosslessStringConvertible {
    func toData() -> Data? {
        return description.data(using: .utf8)
    }

    init?(data: Data) {
        let str = String(data: data, encoding: .utf8)
        if str == nil { return nil }
        self.init(str!)
    }
}
