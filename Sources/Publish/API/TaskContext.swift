//
//  File.swift
//  
//
//  Created by Matthaus Woolard on 02/05/2024.
//

import Foundation

public enum TaskContext {
    public struct Item {
        public let path: Path
        public let section: (any WebsiteSectionID)?
    }
    
    @TaskLocal
    public static var item: Item?
}


internal extension TaskContext.Item {
    func with(path: Path) -> Self {
        Self(path: path, section: self.section)
    }
    static func at(path: Path) -> Self {
        Self(path: path, section: nil)
    }
}
