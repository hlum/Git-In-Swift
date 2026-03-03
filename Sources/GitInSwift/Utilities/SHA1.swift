import Foundation
import CryptoKit

func sha1(_ data: Data) -> String {
    let digest = Insecure.SHA1.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}