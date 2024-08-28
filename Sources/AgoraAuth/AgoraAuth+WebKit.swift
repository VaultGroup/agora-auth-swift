//
//  AgoraAuth+WebKit.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation
import WebKit


extension AgoraAuth: WKUIDelegate, WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let clientConfig = self.clientConfig else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Invalid client config")
            return
        }
        
        guard let redirectUrl = URLComponents(string: clientConfig.redirectUri) else {
            self.delegate?.agoraAuth(error: "AgoraAuth: Unable to determine scheme from redirect URI")
            return
        }
        
        if let url = navigationAction.request.url, url.scheme == redirectUrl.scheme {
            // Cancel the webview navigation, we'll handle it here
            decisionHandler(.cancel)
            // Call the default app delegate redirect handler
            self.webViewNavigationController?.dismiss(animated: true) {
                if let appDelegate = UIApplication.shared.delegate {
                    _ = appDelegate.application?(UIApplication.shared, open: url, options: [:])
                }
            }
            return
        }
        // Follow legit redirects
        decisionHandler(.allow)
    }
}
