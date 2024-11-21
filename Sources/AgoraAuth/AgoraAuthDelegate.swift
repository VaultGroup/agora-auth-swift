//
//  AgoraAuthDelegate.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public protocol AgoraAuthDelegate: AnyObject {
    
    /// The auth flow completed successfully
    func agoraAuth(success code: String, config: AgoraClientConfig, state: [String: Any])
    
    /// The auth flow completed with an error
    func agoraAuth(error: AgoraAuthError)
    
    /// Asks the delegate to return a client config
    func agoraAuth(clientConfig result: @escaping (AgoraClientConfig?) -> Void)
    
    /// You can return any values in the handler and it will be included in the `state` argument of the oauth request. For Agora Authentication,
    /// you can optionally include `source_redirect_url` and `authorize_url` and they will override any default values this library assigns.
    /// The default value for `source_redirect_url` will be `AgoraClientConfig.redirectUri`. Note that the sign in web view redirects will
    /// only be intercepted for schemes matching `AgoraClientConfig.redirectUri`.
    func agoraAuth(authState clientConfig: AgoraClientConfig, oauthConfig: AgoraOauthConfig, result: @escaping ([String:Any]) -> Void)
}

