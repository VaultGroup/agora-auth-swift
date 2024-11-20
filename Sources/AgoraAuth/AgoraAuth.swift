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
    
    public static let shared = AgoraAuth()
    private override init() {}
    
    internal weak var delegate: AgoraAuthDelegate?
    internal var clientConfig: AgoraClientConfig?
    internal var oauthConfig: AgoraOauthConfig?
    
    private weak var presenter: UIViewController?
    
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
                self.delegate?.agoraAuth(error: .invalidClientConfig("Missing client config"))
                return
            }
            // Store the client config
            self.clientConfig = config
            
            // Fetch the oauth config from the server
            self.fetchOpenidConfiguration(config: config) { [weak self] oauthConfig in
                guard let self else { return }
                guard let oauthConfig else {
                    self.delegate?.agoraAuth(error: .invalidClientConfig("Missing oauth config"))
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
    
    private func fetchOpenidConfiguration(config: AgoraClientConfig, result: @escaping (AgoraOauthConfig?) -> Void) {
        let issuer_config = config.issuer + "/.well-known/openid-configuration"
        guard let issuer_config_url = URLComponents(string: issuer_config) else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Invalid openid config URL"))
            result(nil)
            return
        }
        
        var request = URLRequest(url: issuer_config_url.url!)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { [weak delegate] data, response, error in
            DispatchQueue.main.async {
                if let error {
                    delegate?.agoraAuth(error: .serverError(error.localizedDescription))
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    delegate?.agoraAuth(error: .serverError(String(describing: response)))
                    result(nil)
                    return
                }
                
                guard let data else {
                    delegate?.agoraAuth(error: .serverError("No data response from server"))
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    delegate?.agoraAuth(error: .parseError("Error parsing oauth config response from issuer"))
                    result(nil)
                    return
                }
                
                guard
                    let authUrl = json["authorization_endpoint"] as? String,
                    let tokenUrl = json["token_endpoint"] as? String,
                    let userInfoUrl = json["userinfo_endpoint"] as? String
                else {
                    delegate?.agoraAuth(error: .parseError("Missing required oauth config properties from issuer openid config"))
                    result(nil)
                    return
                }
                
                // Completion handler returns on delegate queue, move back the main thread to proceed
                DispatchQueue.main.async {
                    let oauthConfig = AgoraOauthConfig(issuer: config.issuer, authUrl: authUrl, tokenUrl: tokenUrl, userInfoUrl: userInfoUrl)
                    result(oauthConfig)
                }
                
            }
        }
        task.resume()
    }
    
    private func requestAuthCode(clientConfig: AgoraClientConfig, oauthConfig: AgoraOauthConfig, authState: AgoraAuthState) {
        let jsonData = try! JSONSerialization.data(withJSONObject: authState.dictionary)
        let stateData = String(data: jsonData, encoding: .utf8)
        
        guard var authUrl = URLComponents(string: oauthConfig.authUrl) else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Invalid auth URL"))
            return
        }
        
        authUrl.queryItems = [
            URLQueryItem(name: "redirect_uri", value: clientConfig.redirectUri),
            URLQueryItem(name: "nonce", value: UUID().uuidString),
            URLQueryItem(name: "scope", value: clientConfig.scope),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "state", value: stateData),
            URLQueryItem(name: "$interstitial_email_federation", value: "true"),
            URLQueryItem(name: "client_id", value: clientConfig.clientId),
            URLQueryItem(name: "code_challenge", value: clientConfig.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "login_hint", value: clientConfig.loginHint ?? ""),
        ]
        
        guard let url = authUrl.url else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Unable to generate auth URL"))
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
            print("AgoraAuth: Cancelled")
        }
    }
    
    public func handleRedirect(url: URL) -> Bool {
        guard
            let clientConfig = self.clientConfig,
            let redirectUrl = URLComponents(string: clientConfig.redirectUri),
            let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
            redirectUrl.host == components.host
        else {
            // Redirect doesnt match our client config, debounce
            return false
        }
        
        // short circuit on error
        if let error = self.queryItem(from: components, name: "error") {
            if let desc = self.queryItem(from: components, name: "error_description") {
                self.delegate?.agoraAuth(error: .authError("\(error) \(desc)"))
            } else {
                self.delegate?.agoraAuth(error: .authError(error))
            }
            return true
        }
        
        guard let code = self.queryItem(from: components, name: "code") else {
            self.delegate?.agoraAuth(error: .authError("auth code not found in redirect URL"))
            return true
        }
        
        guard
            let state64 = self.queryItem(from: components, name: "state"),
            let stateData = state64.data(using: .utf8),
            let state = try? JSONSerialization.jsonObject(with: stateData, options: []) as? [String: Any]
        else {
            self.delegate?.agoraAuth(error: .authError("Unable to determine state from redirect URL"))
            return true
        }
        
        self.delegate?.agoraAuth(success: code, config: clientConfig, state: [:])
        return true
    }
    
    /// Requires a valid client config, including the client secret.
    /// Requires a valid oauth config, and that it contains a user info URL.
    public func exchangeAuthCode(code: String, result: @escaping (String?) -> Void) {
        guard let clientConfig = self.clientConfig else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Missing client config"))
            result(nil)
            return
        }
        
        guard let oauthConfig = self.oauthConfig else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Missing oauth config"))
            result(nil)
            return
        }
        
        guard let clientSecret = clientConfig.clientSecret else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Unknown client secret, cannot exchange auth code"))
            result(nil)
            return
        }
        
        var tokenUrl = URLComponents(string: oauthConfig.tokenUrl)!
        tokenUrl.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: clientConfig.redirectUri),
            URLQueryItem(name: "code_verifier", value: clientConfig.codeVerifier),
        ]
        
        let authString = [clientConfig.clientId, clientSecret].joined(separator: ":")
        guard let auth64 = authString.data(using: .utf8)?.base64EncodedString() else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Error encoding authorization string"))
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
                    self.delegate?.agoraAuth(error: .serverError(error.localizedDescription))
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    self.delegate?.agoraAuth(error: .serverError(String(describing: response)))
                    result(nil)
                    return
                }
                
                guard let data else {
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    self.delegate?.agoraAuth(error: .parseError("JSON parse error from token endpoint"))
                    result(nil)
                    return
                }
                
                guard let accessToken = json["access_token"] as? String else {
                    let error = json["error"] as? String
                    self.delegate?.agoraAuth(error: .serverError(error ?? "Unknown server error, no access token returned"))
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
            self.delegate?.agoraAuth(error: .invalidClientConfig("Missing oauth config"))
            result(nil)
            return
        }
        
        guard let url = URL(string: oauthConfig.userInfoUrl) else {
            self.delegate?.agoraAuth(error: .invalidClientConfig("Missing user info URL"))
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
                    self.delegate?.agoraAuth(error: .serverError("Request error \(error.localizedDescription)"))
                    result(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    self.delegate?.agoraAuth(error: .serverError("Server request failed \(String(describing: response))"))
                    result(nil)
                    return
                }
                
                guard let data else {
                    self.delegate?.agoraAuth(error: .serverError("No data response from server"))
                    result(nil)
                    return
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?] else {
                    self.delegate?.agoraAuth(error: .parseError("JSON parse error from user info response"))
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
