//
//  AgoraAuthError.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public enum AgoraAuthError: Error {
    case invalidClientConfig(_ message: String)
    case serverError(_ message: String)
    case parseError(_ message: String)
    case authError(_ message: String)
}

