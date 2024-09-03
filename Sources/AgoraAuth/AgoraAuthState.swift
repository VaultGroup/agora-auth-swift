//
//  AgoraAuthState.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public struct AgoraAuthState {
    private let source_redirect_url: String
    private let authorize_url: String
    private var other: [String: Any]
    
    public init(source_redirect_url: String, authorize_url: String, state: [String: Any] = [:]) {
        self.source_redirect_url = source_redirect_url
        self.authorize_url = authorize_url
        self.other = state
    }
    
    var dictionary: [String: Any] {
        var state = self.other
        state["source_redirect_url"] = self.source_redirect_url
        state["authorize_url"] = self.authorize_url
        return state
    }
}
