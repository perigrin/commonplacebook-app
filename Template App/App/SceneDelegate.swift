//
//  SceneDelegate.swift
//  Template App
//
//  Created by Chris Prather on 5/1/25.
//

#if os(iOS)
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Create the SwiftUI view that provides the window contents.
        let homeView = HomeView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)

        // Initialize app coordinator
        appCoordinator = AppCoordinator()
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: homeView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // Handle any deep links or universal links
        if let userActivity = connectionOptions.userActivities.first {
            appCoordinator?.handleUniversalLink(userActivity)
        }
        
        // Handle any notifications
        if let notification = connectionOptions.notificationResponse {
            handleNotification(notification)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        PersistenceController.shared.saveContext()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            appCoordinator?.handleDeepLink(url)
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        appCoordinator?.handleUniversalLink(userActivity)
    }
    
    // MARK: - Private Methods
    
    private func handleNotification(_ response: UNNotificationResponse) {
        appCoordinator?.handlePushNotification(response.notification.request.content.userInfo)
    }
}
#endif
