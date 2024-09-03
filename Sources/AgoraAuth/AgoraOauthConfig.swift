//
//  AgoraOauthConfig.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public struct AgoraOauthConfig {
    public let issuer: String
    public let authUrl: String
    public let tokenUrl: String
    public let userInfoUrl: String
    
    public init(issuer: String, authUrl: String, tokenUrl: String, userInfoUrl: String) {
        self.issuer = issuer
        self.authUrl = authUrl
        self.tokenUrl = tokenUrl
        self.userInfoUrl = userInfoUrl
    }
}
