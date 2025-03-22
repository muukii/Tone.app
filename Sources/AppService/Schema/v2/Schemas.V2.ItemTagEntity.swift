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
  public final class ItemTag: Hashable {
    
    @Attribute(.unique)
    public var identifier: String?
    
    public var name: String
    
    @Relationship(inverse: \Item.tags)
    public var items: [Item] = []
    
    public init(name: String) {
      self.name = name
    }
  }
}

