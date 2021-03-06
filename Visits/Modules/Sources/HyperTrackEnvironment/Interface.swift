import ComposableArchitecture
import Utility
import Types
import UIKit


public struct HyperTrackEnvironment {
  public var checkDeviceTrackability: () -> Effect<UntrackableReason?, Never>
  public var didFailToRegisterForRemoteNotificationsWithError: (String) -> Effect<Never, Never>
  public var didReceiveRemoteNotification: ([String : [String : String]], @escaping (UIBackgroundFetchResult) -> Void) -> Effect<Never, Never>
  public var didRegisterForRemoteNotificationsWithDeviceToken: (Data) -> Effect<Never, Never>
  public var makeSDK: (PublishableKey) -> Effect<SDKStatusUpdate, Never>
  public var openSettings: () -> Effect<Never, Never>
  public var registerForRemoteNotifications: () -> Effect<Never, Never>
  public var requestAlwaysLocationPermissions: () -> Effect<Never, Never>
  public var requestWhenInUseLocationPermissions: () -> Effect<Never, Never>
  public var requestMotionPermissions: () -> Effect<SDKStatusUpdate, Never>
  public var setDriverID: (DriverID) -> Effect<Never, Never>
  public var startTracking: () -> Effect<Never, Never>
  public var stopTracking: () -> Effect<Never, Never>
  public var subscribeToStatusUpdates: () -> Effect<SDKStatusUpdate, Never>
  public var syncDeviceSettings: () -> Effect<Never, Never>

  public init(
    checkDeviceTrackability: @escaping () -> Effect<UntrackableReason?, Never>,
    didFailToRegisterForRemoteNotificationsWithError: @escaping (String) -> Effect<Never, Never>,
    didReceiveRemoteNotification: @escaping ([String : [String : String]], @escaping (UIBackgroundFetchResult) -> Void) -> Effect<Never, Never>,
    didRegisterForRemoteNotificationsWithDeviceToken:  @escaping (Data) -> Effect<Never, Never>,
    makeSDK: @escaping (PublishableKey) -> Effect<SDKStatusUpdate, Never>,
    openSettings: @escaping () -> Effect<Never, Never>,
    registerForRemoteNotifications: @escaping () -> Effect<Never, Never>,
    requestAlwaysLocationPermissions: @escaping () -> Effect<Never, Never>,
    requestWhenInUseLocationPermissions: @escaping () -> Effect<Never, Never>,
    requestMotionPermissions: @escaping () -> Effect<SDKStatusUpdate, Never>,
    setDriverID: @escaping (DriverID) -> Effect<Never, Never>,
    startTracking: @escaping () -> Effect<Never, Never>,
    stopTracking: @escaping () -> Effect<Never, Never>,
    subscribeToStatusUpdates: @escaping () -> Effect<SDKStatusUpdate, Never>,
    syncDeviceSettings: @escaping () -> Effect<Never, Never>
  ) {
    self.checkDeviceTrackability = checkDeviceTrackability
    self.didFailToRegisterForRemoteNotificationsWithError = didFailToRegisterForRemoteNotificationsWithError
    self.didReceiveRemoteNotification = didReceiveRemoteNotification
    self.didRegisterForRemoteNotificationsWithDeviceToken = didRegisterForRemoteNotificationsWithDeviceToken
    self.makeSDK = makeSDK
    self.openSettings = openSettings
    self.registerForRemoteNotifications = registerForRemoteNotifications
    self.requestAlwaysLocationPermissions = requestAlwaysLocationPermissions
    self.requestWhenInUseLocationPermissions = requestWhenInUseLocationPermissions
    self.requestMotionPermissions = requestMotionPermissions
    self.setDriverID = setDriverID
    self.startTracking = startTracking
    self.stopTracking = stopTracking
    self.subscribeToStatusUpdates = subscribeToStatusUpdates
    self.syncDeviceSettings = syncDeviceSettings
  }
}
