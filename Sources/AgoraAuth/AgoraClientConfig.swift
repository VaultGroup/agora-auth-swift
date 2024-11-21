//
//  AgoraClientConfig.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public struct AgoraClientConfig {
    public let clientId: String
    public let redirectUri: String
    public let issuer: String
    public let authorityId: String?
    
    /// A space delimited list of scopes being requested
    public var scope: String = "openid offline_access email profile"
    
    /// The client secret that can be used to make requests to the IDP. Not all implementations
    /// require this secure key, consider whether you need to expose this secret client side.
    public var clientSecret: String?
    
    public var loginHint: String?
    
    public let codeVerifier: String
    public let codeChallenge: String
    
    /// PKCE code verifier and challenge will be generated on init
    public init(
        clientId: String,
        redirectUri: String,
        issuer: String,
        authorityId: String? = nil,
        scope: String = "openid offline_access email profile",
        clientSecret: String? = nil,
        loginHint: String
    ) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.issuer = issuer
        self.authorityId = authorityId
        self.scope = scope
        self.clientSecret = clientSecret
        self.loginHint = loginHint
        
        self.codeVerifier = AgoraPkce.generateCodeVerifier()
        self.codeChallenge = AgoraPkce.generateCodeChallenge(from: codeVerifier)
    }
}
