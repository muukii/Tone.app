//
//  Schemas.V3.ItemTag.swift
//  Tone
//
//  Created by Muukii on 2025/03/23.
//  Copyright © 2025 MuukLab. All rights reserved.
//

import SwiftData
import Foundation

extension Schemas.V3 {
  @Model
  public final class Tag: Hashable, TagType {
        
    public var name: String?
        
    public var lastUsedAt: Date?
    
    @Relationship(
      deleteRule: .nullify,
      inverse: \Schemas.V3.Item.tags
    )
    public var items: [Schemas.V3.Item] = []
    
    public init(name: String) {
      self.name = name
    }
    
    public func markAsUsed() {
      self.lastUsedAt = .init()
    }
  }
}
