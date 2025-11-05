//
//  Constants.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
// UIKit code here
#elseif os(macOS)
import AppKit
// AppKit code here
#endif
/// App-wide constants
enum Constants {
    
    /// API-related constants
    enum API {
        /// Base URL for API requests
        static let baseURL = "https://api.example.com"
        
        /// API version
        static let version = "v1"
        
        /// API timeout in seconds
        static let timeout: TimeInterval = 30
        
        /// API request headers
        static let headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
    
    /// User interface related constants
    enum UI {
        /// Standard corner radius for rounded views
        static let cornerRadius: CGFloat = 8
        
        /// Standard animation duration
        static let animationDuration: TimeInterval = 0.3
        
        /// Standard padding values
        enum Padding {
            /// Extra small padding (4 points)
            static let xs: CGFloat = 4
            
            /// Small padding (8 points)
            static let small: CGFloat = 8
            
            /// Medium padding (16 points)
            static let medium: CGFloat = 16
            
            /// Large padding (24 points)
            static let large: CGFloat = 24
            
            /// Extra large padding (32 points)
            static let xl: CGFloat = 32
        }
        
        /// Font sizes
        enum FontSize {
            /// Caption font size (12 points)
            static let caption: CGFloat = 12
            
            /// Body font size (16 points)
            static let body: CGFloat = 16
            
            /// Title font size (20 points)
            static let title: CGFloat = 20
            
            /// Headline font size (24 points)
            static let headline: CGFloat = 24
            
            /// Large title font size (34 points)
            static let largeTitle: CGFloat = 34
        }
    }
    
    /// App-wide notification names
    enum Notifications {
        /// Posted when user authentication state changes
        static let authStateChanged = Notification.Name("AuthStateChanged")
        
        /// Posted when user profile is updated
        static let userProfileUpdated = Notification.Name("UserProfileUpdated")
        
        /// Posted when app needs to refresh data
        static let refreshDataNeeded = Notification.Name("RefreshDataNeeded")
    }
    
    /// UserDefaults keys
    enum UserDefaultsKeys {
        /// User session key
        static let userSessionKey = "UserSession"
        
        /// App theme setting key
        static let appThemeKey = "AppTheme"
        
        /// Last sync date key
        static let lastSyncDateKey = "LastSyncDate"
        
        /// Onboarding completed key
        static let onboardingCompletedKey = "OnboardingCompleted"
    }
    
    /// Feature flag keys
    enum FeatureFlags {
        /// Feature flag for dark mode
        static let darkModeEnabled = "DarkModeEnabled"
        
        /// Feature flag for analytics
        static let analyticsEnabled = "AnalyticsEnabled"
        
        /// Feature flag for push notifications
        static let pushNotificationsEnabled = "PushNotificationsEnabled"
    }
}
