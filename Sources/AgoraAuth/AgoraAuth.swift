//
//  AgoraAuth.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation
import UIKit.UIViewController
import WebKit


public class AgoraAuth: NSObject {
    
    public struct ClientConfig {
        public let clientId: String
        public let redirectUri: String
        public let issuer: String
        
        /// A space delimited list of scopes being requested
        public var scope: String = "openid offline_access device_sso email profile"
        
        /// The client secret that can be used to make requests to the IDP. Not all implementations
        /// require this secure key, consider whether you need to expose this secret client side.
        public var clientSecret: String?
        
        public init(clientId: String, redirectUri: String, issuer: String, scope: String = "openid offline_access device_sso email profile", clientSecret: String? = nil) {
            self.clientId = clientId
            self.redirectUri = redirectUri
            self.issuer = issuer
            self.scope = scope
            self.clientSecret = clientSecret
        }
    }
    
    public struct OauthConfig {
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
    
    public static let shared = AgoraAuth()
    private override init() {}
    
    private weak var presenter: UIViewController?
    internal weak var delegate: AgoraAuthDelegate?
    
    internal var clientConfig: ClientConfig?
    internal var oauthConfig: OauthConfig?
    
    internal var webViewNavigationController: UINavigationController?
    private var webViewController: UIViewController?
    private var webView: WKWebView!
    
    private func queryItem(from components: NSURLComponents, name: String) -> String? {
        return components.queryItems?.first(where: { $0.name == name })?.value
    }
    
    /// Begin the sign in flow. AgoraAuth will ask the delegate for the required information before opening a
    /// web view for the user to sign in.
    public func signIn(handler: AgoraAuthHandler) {
        self.signIn(presenter: handler, delegate: handler)
    }
    
    /// Begin the sign in flow. AgoraAuth will ask the delegate for the required information before opening a
    /// web view for the user to sign in.
    public func signIn(presenter: UIViewController, delegate: AgoraAuthDelegate) {
        self.presenter = presenter
        self.delegate = delegate
        
        // Fetch the client config from the delegate
        delegate.agoraAuth { [weak self] clientConfig in
            guard let self else { return }
            guard let config = clientConfig else {
                self.delegate?.agoraAuth(error: "AgoraAuth: Missing client config")
                return
            }
            // Store the client config
            self.clientConfig = config
            
            // Fetch the oauth config from the server
            self.fetchOpenidConfiguration(config: config) { [weak self] oauthConfig in
                guard let self else { return }
                guard let oauthConfig else {
                    self.delegate?.agoraAuth(error: "AgoraAuth: Missing oauth config")
                    return
                }
                // Store the oauth config
                self.oauthConfig = oauthConfig
                
                // Fetch the auth state and request the auth code
                self.delegate?.agoraAuth(authState: config, oauthConfig: oauthConfig, result: { [weak self] authState in
                    guard let self else { return }
                    self.requestAuthCode(clientConfig: config, oauthConfig: oauthConfig, authState: authState)
                })
            }
        }
    }
    
    private func fetchOpenidConfiguration(config: ClientConfig, result: @escaping (OauthConfig?) -> Void) {
        let issuer_config = config.issuer + "/.well-known/openid-configuration"
        guard let issuer_config_url = URLComponents(string: issuer_config) else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Invalid openid config URL")
            result(nil)
            return
        }
        
        var request = URLRequest(url: issuer_config_url.url!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { [weak delegate] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    delegate?.agoraAuth(error: "AgoraAuth: \(error.localizedDescription)")
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    delegate?.agoraAuth(error: "AgoraAuth Server error: \(String(describing: response))")
                    result(nil)
                    return
                }
                
                guard let data else {
                    delegate?.agoraAuth(error: "AgoraAuth: No data response from server")
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    delegate?.agoraAuth(error: "AgoraAuth: Error parsing oauth config")
                    result(nil)
                    return
                }
                
                guard
                    let authUrl = json["authorization_endpoint"] as? String,
                    let tokenUrl = json["token_endpoint"] as? String,
                    let userInfoUrl = json["userinfo_endpoint"] as? String
                else {
                    delegate?.agoraAuth(error: "AgoraAuth: Missing required oauth config properties")
                    result(nil)
                    return
                }
                
                // Completion handler returns on delegate queue, move back the main thread to proceed
                DispatchQueue.main.async {
                    let oauthConfig = OauthConfig(issuer: config.issuer, authUrl: authUrl, tokenUrl: tokenUrl, userInfoUrl: userInfoUrl)
                    result(oauthConfig)
                }
                
            }
        }
        task.resume()
    }
    
    private func requestAuthCode(clientConfig: ClientConfig, oauthConfig: OauthConfig, authState: Encodable) {
        let jsonData = try! JSONEncoder().encode(authState)
        let state64 = jsonData.base64EncodedString()
        
        guard var authUrl = URLComponents(string: oauthConfig.authUrl) else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Invalid auth URL")
            return
        }
        
        authUrl.queryItems = [
            URLQueryItem(name: "redirect_uri", value: clientConfig.redirectUri),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "scope", value: clientConfig.scope),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "state", value: state64),
            URLQueryItem(name: "$interstitial_email_federation", value: "true"),
            URLQueryItem(name: "client_id", value: clientConfig.clientId),
        ]
        
        guard let url = authUrl.url else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Unable to generate auth URL")
            return
        }
        // NOTE: Auth code will be acquired on redirect!
        self.present(authUrl: url)
    }
    
    private func present(authUrl: URL) {
        webView = WKWebView(frame: .zero)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        self.webViewController = UIViewController()
        self.webViewController!.view = webView
        self.webViewController!.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.webViewCancelled(_:)))
        self.webViewNavigationController = UINavigationController(rootViewController: webViewController!)
        
        self.presenter?.present(self.webViewNavigationController!, animated: true) {
            let req = URLRequest(url: authUrl)
            self.webView.load(req)
        }
    }
    
    @objc func webViewCancelled(_ sender: Any?) {
        self.webViewNavigationController?.dismiss(animated: true) {
            self.delegate?.agoraAuth(error: "AgoraAuth: Cancelled")
        }
    }
    
    public func handleRedirect(url: URL) -> Bool {
        guard
            let redirectUrl = URLComponents(string: clientConfig?.redirectUri ?? ""),
            let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
            redirectUrl.host == components.host
        else {
            // Redirect doesnt match our client config, debounce
            return false
        }
        
        // short circuit on error
        if let error = self.queryItem(from: components, name: "error") {
            if let desc = self.queryItem(from: components, name: "error_description") {
                self.delegate?.agoraAuth(error: "AgoraAuth: \(error) \(desc)")
            } else {
                self.delegate?.agoraAuth(error: "AgoraAuth: \(error)")
            }
            return true
        }
        
        guard let code = self.queryItem(from: components, name: "code") else {
            self.delegate?.agoraAuth(error: "AgoraAuth: auth code not found in redirect URL")
            return true
        }
        
        guard
            let state64 = self.queryItem(from: components, name: "state"),
            let stateData = Data(base64Encoded: state64),
            let state = try? JSONSerialization.jsonObject(with: stateData, options: []) as? [String: Any]
        else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Unable to determine state from redirect URL")
            return true
        }
        
        self.delegate?.agoraAuth(success: code, state: state)
        return true
    }
    
    /// Requires a valid client config, including the client secret.
    /// Requires a valid oauth config, and that it contains a user info URL.
    public func exchangeAuthCode(code: String, result: @escaping (String?) -> Void) {
        guard let clientConfig = self.clientConfig else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Invalid client config")
            result(nil)
            return
        }
        
        guard let oauthConfig = self.oauthConfig else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Invalid oauth config")
            result(nil)
            return
        }
        
        guard let clientSecret = clientConfig.clientSecret else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Unknown client secret, cannot exchange auth code")
            result(nil)
            return
        }
        
        var tokenUrl = URLComponents(string: oauthConfig.tokenUrl)!
        tokenUrl.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: clientConfig.redirectUri),
        ]
        
        let authString = [clientConfig.clientId, clientSecret].joined(separator: ":")
        guard let auth64 = authString.data(using: .utf8)?.base64EncodedString() else {
            self.delegate?.agoraAuth(error: "Error during request: Error encoding authorization string")
            result(nil)
            return
        }
        
        var request = URLRequest(url: tokenUrl.url!)
        request.httpMethod = "POST"
        request.addValue("Basic " + auth64, forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else {
                    result(nil)
                    return
                }
                
                if let error {
                    self.delegate?.agoraAuth(error: "Error during request: \(error.localizedDescription)")
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    self.delegate?.agoraAuth(error: "Server error: \(String(describing: response))")
                    result(nil)
                    return
                }
                
                guard let data else {
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    self.delegate?.agoraAuth(error: "AgoraAuth: JSON parse error")
                    result(nil)
                    return
                }
                
                guard let accessToken = json["access_token"] as? String else {
                    let error = json["error"] as? String ?? ""
                    self.delegate?.agoraAuth(error: "AgoraAuth Error: \(error)")
                    result(nil)
                    return
                }
                
                // SUCCESS
                result(accessToken)
            }
        }
        
        task.resume()
    }
    
    /// Requires a valid oauth config, and that it contains a user info URL
    public func fetchUserInfo(accessToken: String, result: @escaping ([String: Any?]?) -> Void) {
        guard let oauthConfig = self.oauthConfig else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Missing oauth config")
            result(nil)
            return
        }
        
        guard let url = URL(string: oauthConfig.userInfoUrl) else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Missing user info URL")
            result(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer " + accessToken, forHTTPHeaderField: "Authorization")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else {
                    result(nil)
                    return
                }
                
                if let error = error {
                    self.delegate?.agoraAuth(error: "AgoraAuth: Request error \(error.localizedDescription)")
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    self.delegate?.agoraAuth(error: "AgoraAuth: Server request failed \(String(describing: response))")
                    result(nil)
                    return
                }
                
                guard let data else {
                    self.delegate?.agoraAuth(error: "AgoraAuth: No data response from server")
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?] else {
                    self.delegate?.agoraAuth(error: "AgoraAuth: JSON parse error")
                    result(nil)
                    return
                }
                
                // SUCCESS
                result(json)
            }
        }
        
        task.resume()
    }
}
