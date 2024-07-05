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
        public let metadata: (any WebsiteItemMetadata)?
    }
    
    
    @TaskLocal
    public static var item: Item?
    
    @TaskLocal
    public static var domain: TaskContextDomain?
    
    static let websiteDomain = WebsiteGeneration()
    static let rssDomain = RSSFeedGeneration()
    static let podcastDomain = PodcastGeneration()
    
    public struct WebsiteGeneration: TaskContextDomain {}
    public struct RSSFeedGeneration: TaskContextDomain {}
    public struct PodcastGeneration: TaskContextDomain {}
}

public protocol TaskContextDomain {}




internal extension TaskContext.Item {
    func with(path: Path) -> Self {
        Self(path: path, section: self.section, metadata: nil)
    }
    
    static func at(path: Path) -> Self {
        Self(path: path, section: nil, metadata: nil)
    }
    
    func with<M: WebsiteItemMetadata>(metadata: M) -> Self {
        Self(path: self.path, section: self.section, metadata: metadata)
    }
}

extension TaskLocal<Optional<TaskContext.Item>> {
    func with<M: WebsiteItemMetadata, R>(metadata: M, _ block: () throws -> R) rethrows -> R {
        guard let value = self.wrappedValue else {
            return try block()
        }
        return try self.withValue(value.with(metadata: metadata), operation: block)
    }
}
