//
//  AgoraAuthError.swift
//
//  Created by Will Connelly on 23/8/2024.
//  Copyright © 2024 MRI Software LLC. All rights reserved.
//

import Foundation


public enum AgoraAuthError: Error {
    case invalidClientConfig(message: String)
    case serverError(message: String)
    case parseError(message: String)
    case authError(message: String)
}

