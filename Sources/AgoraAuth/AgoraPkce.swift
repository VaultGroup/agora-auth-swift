//
//  AgoraPkce.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation
import CommonCrypto


public class AgoraPkce {
    
    public static func generateCodeVerifier(length: Int = 64) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    public static func generateCodeChallenge(from verifier: String) -> String {
        guard let verifierData = verifier.data(using: .utf8) else { return "" }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        verifierData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(verifierData.count), &hash)
        }
        
        let data = Data(hash)
        return data.base64EncodedString(options: .endLineWithLineFeed)
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
