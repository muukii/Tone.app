//
//  Schemas.V2.ItemTag.swift
//  Tone
//
//  Created by Muukii on 2025/03/23.
//  Copyright © 2025 MuukLab. All rights reserved.
//

import SwiftData
import Foundation

extension Schemas.V2 {
  @Model
  public final class Tag: Hashable, TagType {
        
    public var name: String?
        
    public var lastUsedAt: Date?
    
    public init(name: String) {
      self.name = name
    }
    
    public func markAsUsed() {
      self.lastUsedAt = .init()
    }
  }
}

