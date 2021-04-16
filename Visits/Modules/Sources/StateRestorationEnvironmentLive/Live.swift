import ComposableArchitecture
import LogEnvironment
import NonEmpty
import Prelude
import StateRestorationEnvironment
import Types



public extension StateRestorationEnvironment {
  static let live = StateRestorationEnvironment(
    loadState: {
      Effect<StorageState?, Never>.result {
        logEffect("loadState")
        return .success(
          restoredStateFrom(
            screen: UserDefaults.standard.string(forKey: RestorationKey.screen.rawValue)
              >>- Screen.init(rawValue:),
            email: UserDefaults.standard.string(forKey: RestorationKey.email.rawValue)
              >>- NonEmptyString.init(rawValue:)
              <¡> Email.init(rawValue:),
            publishableKey: UserDefaults.standard.string(forKey: RestorationKey.publishableKey.rawValue)
              >>- NonEmptyString.init(rawValue:)
              <¡> PublishableKey.init(rawValue:),
            driverID: UserDefaults.standard.string(forKey: RestorationKey.driverID.rawValue)
              >>- NonEmptyString.init(rawValue:)
              <¡> DriverID.init(rawValue:),
            orders: (UserDefaults.standard.object(forKey: RestorationKey.orders.rawValue) as? Data)
              >>- { try? JSONDecoder().decode(Set<Order>.self, from: $0) },
            places: (UserDefaults.standard.object(forKey: RestorationKey.places.rawValue) as? Data)
              >>- { try? JSONDecoder().decode(Set<Place>.self, from: $0) },
            tabSelection: (UserDefaults.standard.string(forKey: RestorationKey.tabSelection.rawValue))
              >>- TabSelection.init(rawValue:),
            pushStatus: (UserDefaults.standard.string(forKey: RestorationKey.pushStatus.rawValue))
              >>- PushStatusRestorationKeys.init(rawValue:)
              >-> pushStatus(from:),
            experience: (UserDefaults.standard.string(forKey: RestorationKey.experience.rawValue))
              >>- Experience.restore
          )
        )
      }
    },
    saveState: { s in
      .fireAndForget {
        logEffect("saveState: \(String(describing: s))")
        
        let ud = UserDefaults.standard
        
        switch s {
        case .none:
          for key in RestorationKey.allCases {
            ud.removeObject(forKey: key.rawValue)
          }
        case let .some(s):
          switch s {
          case let .signUp(e):
            ud.set(Screen.signUp.rawValue, forKey: RestorationKey.screen.rawValue)
            ud.set(e <¡> \.string, forKey: RestorationKey.email.rawValue)
          case let .signIn(e):
            ud.set(Screen.signIn.rawValue, forKey: RestorationKey.screen.rawValue)
            ud.set(e <¡> \.string, forKey: RestorationKey.email.rawValue)
          case let .driverID(dID, pk):
            ud.set(Screen.driverID.rawValue, forKey: RestorationKey.screen.rawValue)
            ud.set(dID <¡> \.string, forKey: RestorationKey.driverID.rawValue)
            ud.set(pk <¡> \.string, forKey: RestorationKey.publishableKey.rawValue)
          case let .main(o, p, s, pk, dID, ps, e):
            ud.set(Screen.main.rawValue, forKey: RestorationKey.screen.rawValue)
            ud.set(try? JSONEncoder().encode(o), forKey: RestorationKey.orders.rawValue)
            ud.set(try? JSONEncoder().encode(p), forKey: RestorationKey.places.rawValue)
            ud.set(s.rawValue, forKey: RestorationKey.tabSelection.rawValue)
            ud.set(pk <¡> \.string, forKey: RestorationKey.publishableKey.rawValue)
            ud.set(dID <¡> \.string, forKey: RestorationKey.driverID.rawValue)
            ud.set(pushStatus(from: ps).rawValue, forKey: RestorationKey.pushStatus.rawValue)
            ud.set(e.store(), forKey: RestorationKey.experience.rawValue)
          }
        }
      }
    }
  )
}

func restoredStateFrom(
  screen: Screen?,
  email: Email?,
  publishableKey: PublishableKey?,
  driverID: DriverID?,
  orders: Set<Order>?,
  places: Set<Place>?,
  tabSelection: TabSelection?,
  pushStatus: PushStatus?,
  experience: Experience?
) -> StorageState? {
  switch (screen, email, publishableKey, driverID, orders, places, tabSelection, pushStatus, experience) {
  
  // Old app that got to deliveries screen.
  case let (.none, _, .some(publishableKey), .some(driverID), _, _, _, _, _):
    return .main([], [], .defaultTab, publishableKey, driverID, .dialogSplash(.notShown), .regular)
  
  // Old app that only got to the DriverID screen
  case let (.none, _, .some(publishableKey), .none, _, _, _, _, _):
    return .driverID(nil, publishableKey)
  
  // Freshly installed app that didn't go though the deep link search,
  // or an old app that didn't open the deep link
  case (.none, _, _, .none, .none, _, _, _, _):
    return nil
  
  case let (.signUp, email, _, _, _, _, _, _, _):
    return .signUp(email)
    
  // Sign in screen
  case let (.signIn, email, _, _, _, _, _, _, _):
    return .signIn(email)
  
  // Driver ID screen
  case let (.driverID, _, .some(publishableKey), driverID, _, _, _, _, _):
    return .driverID(driverID, publishableKey)
  
  // Main screen
  case let (.main, _, .some(publishableKey), .some(driverID), orders, places, tabSelection, pushStatus, experience):
    return .main(orders ?? [], places ?? [], tabSelection ?? .defaultTab, publishableKey, driverID, pushStatus ?? .dialogSplash(.notShown), experience ?? .regular)
  
  // State restoration failed, back to the starting screen
  default: return nil
  }
}

enum RestorationKey: String, CaseIterable {
  case driverID = "Hp6XdOsXsw"
  case email = "sXwAlVbnPT"
  case experience = "lQDSheJivt"
  case orders = "nB24HHL2T5"
  case places = "Q8Cg06VCdL"
  case publishableKey = "UeiDZRFEOd"
  case pushStatus = "jC0FVlTWrC"
  case screen = "ZJNLfS0Nhw"
  case tabSelection = "8VGkczct6P"
}

enum Screen: String {
  case signUp
  case signIn
  case driverID
  case main = "visits"
}

enum PushStatusRestorationKeys: String {
  case dialogSplashShown
  case dialogSplashNotShown
  case dialogSplashWaitingForUserAction
}

func pushStatus(from key: PushStatusRestorationKeys) -> PushStatus {
  switch key {
  case .dialogSplashShown:                return .dialogSplash(.shown)
  case .dialogSplashNotShown:             return .dialogSplash(.notShown)
  case .dialogSplashWaitingForUserAction: return .dialogSplash(.waitingForUserAction)
  }
}

func pushStatus(from status: PushStatus) -> PushStatusRestorationKeys {
  switch status {
  case .dialogSplash(.shown):                return .dialogSplashShown
  case .dialogSplash(.notShown):             return .dialogSplashNotShown
  case .dialogSplash(.waitingForUserAction): return .dialogSplashWaitingForUserAction
  }
}

extension Experience {
  private static let firstRunKey = "EMcvpiyTCY"
  private static let regularKey  = "wDvZjD44fJ"
  
  func store() -> String {
    switch self {
    case .firstRun: return Experience.firstRunKey
    case .regular:  return Experience.regularKey
    }
  }
  
  static func restore(_ experience: String) -> Self? {
    switch experience {
    case firstRunKey: return .firstRun
    case regularKey:  return .regular
    default: return nil
    }
  }
}
