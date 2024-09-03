//
//  AgoraAuthDelegate.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public protocol AgoraAuthDelegate: AnyObject {
    func agoraAuth(success code: String, config: AgoraClientConfig, state: [String: Any])
    func agoraAuth(error: AgoraAuthError)
    /// Asks the delegate to return a client config
    func agoraAuth(clientConfig result: @escaping (AgoraClientConfig?) -> Void)
    /// You can return any values in the handler and it will be included in the `state` argument of the oauth request. For Agora Authentication,
    /// you must include `source_redirect_url` and `authorize_url`
    func agoraAuth(authState clientConfig: AgoraClientConfig, oauthConfig: AgoraOauthConfig, result: @escaping (AgoraAuthState) -> Void)
}

