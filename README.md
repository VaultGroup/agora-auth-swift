# AgoraAuth for Swift

A pure Swift Package to simplify the process of Agora authentication, with preconstructed
calls to the identity provider with the required queries and claims. This package is
dependency free.

## Implementation

1. In your Xcode project: File > Add Package Dependencies... > https://github.com/VaultGroup/agora-auth-swift
1. Implement `AgoraAuthDelegate`
1. Call `AgoraAuth.shared.signIn(handler: self)`

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
            issuer: provider.issuer)
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

`AgoraAuth` can handle the redirect after successfully authenticating. Implement the handler in the `AppDelegate`
method 

```swift AppDelegate.swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Check if AgoraAuth can handle the redirect
    if AgoraAuth.shared.handleRedirect(url: url) {
        return true
    }
}
```

Begin the sign in flow by calling one of the public `signIn(:)` methods. You can implement the delegate in your view,
or delegate `AgoraAuth` events to another object.

```swift
// 1. Delegate is implemented in a UIViewController
AgoraAuth.shared.signIn(handler: self)

// 2. Provide a presenter and a delegate
AgoraAuth.shared.signIn(presenter: self, delegate: someDelegate)
```

## Contributions

Contributions are welcome. This project could easily be adapted to work as a generic Oauth client, however certain values
are hardcoded to simplify the API.