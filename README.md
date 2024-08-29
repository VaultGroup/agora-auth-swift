# AgoraAuth for Swift

This Swift Package simplifies the process of Agora authentication with preconstructed
calls to the identity provider with the required queries and claims.

## Implementation

1. In your Xcode project: File > Add Package Dependencies... > https://github.com/VaultGroup/agora-auth-swift
1. Implement `AgoraAuthDelegate`
1. Call AgoraAuth.shared.signIn(handler: self)

## Example

```swift UIViewController+AgoraAuthDelegate.swift
extension UIViewController: AgoraAuthDelegate {
    public func agoraAuth(success code: String, state: [String: Any]) {
        // Agora has successfully authenticated the user, handle the authorization code.
        // NOTE: The auth code needs to be exchange for an access token to make requests
        // to other Agora endpoints
    }
    
    public func agoraAuth(error: String) {
        // Handle any errors here
    }
    
    public func agoraAuth(clientConfig result: @escaping (AgoraAuth.ClientConfig?) -> Void) {
        // Return a client config in the result handler
        let config = AgoraAuth.ClientConfig(
            clientId: provider.clientIdentifier,
            redirectUri: provider.redirectUri,
            issuer: provider.authorityUrl)
        
        result(config)
    }
    
    public func agoraAuth(
        authState clientConfig: AgoraAuth.ClientConfig, 
        oauthConfig: AgoraAuth.OauthConfig, 
        result: @escaping (AgoraAuthState) -> Void
    ) {
        // Return the state argument passed to the auth url. This object will be encoded as a JSON respresentation and
        // returned as a dictionary in `agoraAuth(success:state:)` if the request is successful
        let state = AgoraAuthState(
            source_redirect_url: clientConfig.redirectUri,
            authorize_url: oauthConfig.authUrl)
        result(state)
    }
}
```

AgoraAuth can handle the redirect after successfully authenticating. Implement the handler in the `AppDelegate`
method 

```swift AppDelegate.swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Check if AgoraAuth can handle the redirect
    if AgoraAuth.shared.handleRedirect(url: url) {
        return true
    }
}
```
