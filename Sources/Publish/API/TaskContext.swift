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
        Self(path: path, section: self.section)
    }
    static func at(path: Path) -> Self {
        Self(path: path, section: nil)
    }
}
