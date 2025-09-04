//
//  RecentSearchItem.swift
//  FitSpo
//
//  Model for tracking recent searches that can be either users or hashtags
//

import Foundation

struct RecentSearchItem: Codable, Identifiable, Equatable {
    let id: String
    let type: SearchType
    let timestamp: Date
    
    // User-specific properties
    let userId: String?
    let displayName: String?
    let avatarURL: String?
    
    // Hashtag-specific properties
    let hashtag: String?
    
    enum SearchType: String, Codable {
        case user
        case hashtag
    }
    
    // Create from user
    init(user: UserLite) {
        self.id = "user_\(user.id)"
        self.type = .user
        self.timestamp = Date()
        self.userId = user.id
        self.displayName = user.displayName
        self.avatarURL = user.avatarURL
        self.hashtag = nil
    }
    
    // Create from hashtag
    init(hashtag: String) {
        self.id = "hashtag_\(hashtag)"
        self.type = .hashtag
        self.timestamp = Date()
        self.userId = nil
        self.displayName = nil
        self.avatarURL = nil
        self.hashtag = hashtag
    }
    
    static func == (lhs: RecentSearchItem, rhs: RecentSearchItem) -> Bool {
        return lhs.id == rhs.id
    }
}
