import AppLogic
import AppScreen
import BlockerScreen
import ComposableArchitecture
import DriverIDScreen
import LoadingScreen
import MapScreen
import OrderScreen
import OrdersScreen
import Prelude
import SignInScreen
import SignUpFormScreen
import SignUpQuestionsScreen
import SignUpVerificationScreen
import Types



// MARK: - Life Cycle

public enum LifeCycleAction {
  case finishedLaunching
  case deepLinkOpened(NSUserActivity)
  case receivedPushNotification
  case willEnterForeground
}

public extension ViewStore where State == Prelude.Unit, Action == LifeCycleAction {
  static func lifeCycleViewStore(from store: Store<AppState, AppAction>) -> ViewStore {
    ViewStore(
      store.scope(
        state: { _ in unit },
        action: { a in
          switch a {
          case let .deepLinkOpened(a):    return .deepLinkOpened(a)
          case .finishedLaunching:        return .osFinishedLaunching
          case .receivedPushNotification: return .receivedPushNotification
          case .willEnterForeground:      return .willEnterForeground
          }
        }
      )
    )
  }
}

public func deepLink(from userActivities: Set<NSUserActivity>) -> NSUserActivity? {
  for activity in userActivities {
    if activity.webpageURL != nil {
      return activity
    }
  }
  return nil
}

// MARK: - App Screen

public extension Store where State == AppScreen.State, Action == AppScreen.Action {
  static func appScreenStore(from store: Store<AppState, AppAction>) -> Store {
    store.scope(state: fromAppState, action: toAppAction)
  }
}

func fromAppState(_ appState: AppState) -> AppScreen.State {
  switch appState.flow {
  case .created, .appLaunching, .firstRun: return .loading
  case .noMotionServices: return .blocker(.noMotionServices)
  case let .signUp(.formFilled(n, e, p, focus, err)):
    return .signUpForm(
      .init(
        name: n.rawValue.rawValue,
        email: e.rawValue.rawValue,
        password: p.rawValue.rawValue,
        fieldInFocus: (focus <¡> SignUpFormScreen.State.Focus.init(formFocus:)) ?? .none,
        formIsValid: true,
        questionsAnswered: false,
        errorMessage: err?.rawValue.rawValue ?? ""
      )
    )
  case let .signUp(.formFilling(n, e, p, focus, err)):
    return .signUpForm(
      .init(
        name: n?.rawValue.rawValue ?? "",
        email: e?.rawValue.rawValue ?? "",
        password: p?.rawValue.rawValue ?? "",
        fieldInFocus: (focus <¡> SignUpFormScreen.State.Focus.init(formFocus:)) ?? .none,
        formIsValid: false,
        questionsAnswered: false,
        errorMessage: err?.rawValue.rawValue ?? ""
      )
    )
  case let .signUp(.questions(_, _, _, .signingUp(bm, mf, rs))):
    return .signUpQuestions(.init(questionsStatus: .signingUp(bm, mf, rs)))
  case let .signUp(.questions(_, _, _, .answering(ebmmf, efe))):
    return .signUpQuestions(.init(questionsStatus: .answering(ebmmf, efe)))
  case let .signUp(.verification(ver, _, _)): return .signUpVerification(verificationState(ver))
  
  case let .signIn(s):
    return .signIn(
      .init(
        buttonState: buttonState(from: s),
        email: email(from: s),
        errorMessage: errorMessage(from: s),
        fieldInFocus: fieldInFocus(from: s),
        password: password(from: s),
        signingIn: signingIn(from: s)
      )
    )
  case let .driverID(.some(drID), _):
    return .driverID(.init(driverID: drID.rawValue.rawValue, buttonDisabled: false))
  case .driverID: return .driverID(.init(driverID: "", buttonDisabled: true))
  case let .main(v, sv, h, s, pk, drID, deID, us, p, r, ps, _):
    switch (us, p.locationAccuracy, p.locationPermissions, p.motionPermissions, ps) {
    case (_, _, .disabled, _, _):                            return .blocker(.locationDisabled)
    case (_, _, .denied, _, _):                              return .blocker(.locationDenied)
    case (_, _, .restricted, _, _):                          return .blocker(.locationRestricted)
    case (_, _, .notDetermined, _, _):                       return .blocker(.locationNotDetermined)
    case (_, .reduced, _, _, _):                             return .blocker(.locationReduced)
    case (_, _, _, .disabled, _):                            return .blocker(.motionDisabled)
    case (_, _, _, .denied, _):                              return .blocker(.motionDenied)
    case (_, _, _, .notDetermined, _):                       return .blocker(.motionNotDetermined)
    case (_, _, _, _, .dialogSplash(.notShown)),
         (_, _, _, _, .dialogSplash(.waitingForUserAction)): return .blocker(.pushNotShown)
    case (.deleted, _, _, _, _):                             return .blocker(.deleted(deID.rawValue.rawValue))
    case (.invalidPublishableKey, _, _, _, _):               return .blocker(.invalidPublishableKey(deID.rawValue.rawValue))
    case (.stopped, _, _, _, _):                             return .blocker(.stopped)
    case (.running, .full, .authorized, .authorized, .dialogSplash(.shown)):
      let networkAvailable = appState.network == .online
      let refreshingOrders = r.orders == .refreshingOrders
      let mapOrdersList = mapOrders(from: v)
      
      if let sv = sv {
        return .main(.order(orderScreen(from: sv, pk: pk.rawValue.rawValue, dID: deID.rawValue.rawValue)), h, mapOrdersList, drID, deID, s)
      } else {
        let (pending, visited, completed, canceled) = orderHeaders(from: Array(v))
        return .main(.orders(.init(pending: pending, visited: visited, completed: completed, canceled: canceled, isNetworkAvailable: networkAvailable, refreshing: refreshingOrders, deviceID: deID.rawValue.rawValue, publishableKey: pk.rawValue.rawValue)), h, mapOrdersList, drID, deID, s)
      }
    }
  }
}


func toAppAction(_ appScreenAction: AppScreen.Action) -> AppAction {
  switch appScreenAction {
  case .signUpForm(.nameTapped): return .focusBusinessName
  case let .signUpForm(.nameChanged(n)) where n.isEmpty: return .businessNameChanged(nil)
  case let .signUpForm(.nameChanged(n)): return .businessNameChanged(.init(stringLiteral: n))
  case .signUpForm(.nameEnterKeyboardButtonTapped): return .focusEmail
  case .signUpForm(.emailTapped): return .focusEmail
  case let .signUpForm(.emailChanged(e)) where e.isEmpty: return .emailChanged(nil)
  case let .signUpForm(.emailChanged(e)): return .emailChanged(.init(stringLiteral: e))
  case .signUpForm(.emailEnterKeyboardButtonTapped): return .focusPassword
  case .signUpForm(.passwordTapped): return .focusPassword
  case let .signUpForm(.passwordChanged(p)) where p.isEmpty: return .passwordChanged(nil)
  case let .signUpForm(.passwordChanged(p)): return .passwordChanged(.init(stringLiteral: p))
  case .signUpForm(.passwordEnterKeyboardButtonTapped): return .completeSignUpForm
  case .signUpForm(.nextButtonTapped): return .completeSignUpForm
  case .signUpForm(.signInTapped): return .goToSignIn
  case .signUpForm(.tappedOutsideFocus): return .dismissFocus
  case let .signUpQuestions(.businessManagesChanged(bm)): return .businessManagesChanged(bm)
  case let .signUpQuestions(.managesForChanged(mf)): return .managesForChanged(mf)
  case .signUpQuestions(.businessManagesTapped): return .businessManagesSelected
  case .signUpQuestions(.managesForTapped): return .managesForSelected
  case .signUpQuestions(.deselectQuestions): return .dismissFocus
  case .signUpQuestions(.backButtonTapped): return .goToSignUp
  case .signUpQuestions(.acceptButtonTapped): return .signUp
  case .signUpQuestions(.cancelSignUpTapped): return .cancelSignUp
  case let .signUpVerification(.firstFieldChanged(s)): return .firstVerificationFieldChanged(s)
  case let .signUpVerification(.secondFieldChanged(s)): return .secondVerificationFieldChanged(s)
  case let .signUpVerification(.thirdFieldChanged(s)): return .thirdVerificationFieldChanged(s)
  case let  .signUpVerification(.fourthFieldChanged(s)): return .fourthVerificationFieldChanged(s)
  case let .signUpVerification(.fifthFieldChanged(s)): return .fifthVerificationFieldChanged(s)
  case let .signUpVerification(.sixthFieldChanged(s)): return .sixthVerificationFieldChanged(s)
  case .signUpVerification(.fieldsTapped): return .focusVerification
  case .signUpVerification(.tappedOutsideFocus): return .dismissFocus
  case .signUpVerification(.resendButtonTapped): return .resendVerificationCode
  case .signUpVerification(.signInTapped): return .goToSignIn
  case .signUpVerification(.backspacePressed): return .deleteVerificationDigit
  case .signIn(.cancelSignInTapped): return .cancelSignIn
  case let .signIn(.emailChanged(e)) where e.isEmpty: return .emailChanged(nil)
  case let .signIn(.emailChanged(e)): return .emailChanged(.init(stringLiteral: e))
  case .signIn(.emailEnterKeyboardButtonTapped): return .focusPassword
  case .signIn(.emailTapped): return .focusEmail
  case let .signIn(.passwordChanged(p)) where p.isEmpty: return .passwordChanged(nil)
  case let .signIn(.passwordChanged(p)): return .passwordChanged(.init(stringLiteral: p))
  case .signIn(.passwordEnterKeyboardButtonTapped): return .signIn
  case .signIn(.passwordTapped): return .focusPassword
  case .signIn(.signInTapped): return .signIn
  case .signIn(.tappedOutsideFocus): return .dismissFocus
  case .signIn(.signUpTapped): return .goToSignUp
  case .driverID(.buttonTapped): return .setDriverID
  case let .driverID(.driverIDChanged(d)) where d.isEmpty: return .driverIDChanged(nil)
  case let .driverID(.driverIDChanged(d)): return .driverIDChanged(.init(stringLiteral: d))
  case .driverID(.nextEnterKeyboardButtonTapped): return .setDriverID
  case .blocker(.deletedButtonTapped): return .startTracking
  case .blocker(.invalidPublishableKeyButtonTapped): return .startTracking
  case .blocker(.stoppedButtonTapped): return .startTracking
  case .blocker(.locationDeniedButtonTapped): return .openSettings
  case .blocker(.locationDisabledButtonTapped): return .openSettings
  case .blocker(.locationNotDeterminedButtonTapped): return .requestLocationPermissions
  case .blocker(.locationRestrictedButtonTapped): return .openSettings
  case .blocker(.locationReducedButtonTapped): return .openSettings
  case .blocker(.motionDeniedButtonTapped): return .openSettings
  case .blocker(.motionDisabledButtonTapped): return .openSettings
  case .blocker(.motionNotDeterminedButtonTapped): return .requestMotionPermissions
  case .blocker(.pushNotShownButtonTapped): return .requestPushAuthorization
  case .orders(.clockOutButtonTapped): return .stopTracking
  case .orders(.refreshButtonTapped): return .updateOrders
  case let .orders(.orderTapped(id)): return .selectOrder(id)
  case .order(.backButtonTapped): return .deselectOrder
  case .order(.cancelButtonTapped): return .cancelOrder
  case .order(.checkOutButtonTapped): return .checkOutOrder
  case let .order(.copyTextPressed(t)): return .copyToPasteboard(t)
  case .order(.mapTapped): return .openAppleMaps
  case .order(.noteEnterKeyboardButtonTapped): return .dismissFocus
  case let .order(.noteFieldChanged(d)) where d.isEmpty: return .orderNoteChanged(nil)
  case let .order(.noteFieldChanged(d)): return .orderNoteChanged(.init(stringLiteral: d))
  case .order(.noteTapped): return .focusOrderNote
  case .order(.pickedUpButtonTapped): return .pickUpOrder
  case .order(.tappedOutsideFocusedTextField): return .dismissFocus
  case .tab(.map): return .switchToMap
  case .tab(.orders): return .switchToOrders
  case .tab(.summary): return .switchToSummary
  case .tab(.profile): return .switchToProfile
  case let .map(id): return .selectOrder(id)
  case .tab(.places): return .switchToPlaces
  }
}

func email(from s: SignIn) -> String {
  switch s {
  case let .signingIn(e, _),
       let .editingCredentials(.some(e), _, _, _):
    return e.rawValue.rawValue
  default: return ""
  }
}

func password(from s: SignIn) -> String {
  switch s {
  case let .signingIn(_, p),
       let .editingCredentials(_, .some(p), _, _):
    return p.rawValue.rawValue
  default: return ""
  }
}

func buttonState(from s: SignIn) -> SignInScreen.State.ButtonState {
  switch s {
  case .signingIn:                              return .destructive
  case .editingCredentials(.some, .some, _, _): return .normal
  default:                                      return .disabled
  }
}

func errorMessage(from s: SignIn) -> String {
  switch s {
  case let .editingCredentials(_, _, _, .some(e)):
    return e.rawValue.rawValue
  default: return ""
  }
}

func fieldInFocus(from s: SignIn) -> SignInScreen.State.Focus {
  switch s {
  case .editingCredentials(_, _, .email, _):
    return .email
  case .editingCredentials(_, _, .password, _):
    return .password
  default: return .none
  }
}

func signingIn(from s: SignIn) -> Bool {
  switch s {
  case .signingIn: return true
  default: return false
  }
}

func orderHeaders(from vs: [Order]) -> ([OrderHeader], [OrderHeader], [OrderHeader], [OrderHeader]) {
  var pending: [(Date, OrderHeader)] = []
  var visited: [(Date, OrderHeader)] = []
  var completed: [(Date, OrderHeader)] = []
  var canceled: [(Date, OrderHeader)] = []
  
  for v in vs {
    let t = orderTitle(from: v)
    
    let h = OrderHeader(id: v.id.rawValue.rawValue, title: t)
    switch v.geotagSent {
    case .notSent, .pickedUp: pending.append((v.createdAt, h))
    case .entered, .visited:  visited.append((v.createdAt, h))
    case .checkedOut:         completed.append((v.createdAt, h))
    case .cancelled:          canceled.append((v.createdAt, h))
    }
  }
  return (
    pending.sorted(by: sortHeaders).map(\.1),
    visited.sorted(by: sortHeaders).map(\.1),
    completed.sorted(by: sortHeaders).map(\.1),
    canceled.sorted(by: sortHeaders).map(\.1)
  )
}

func sortHeaders(_ left: (date: Date, order: OrderHeader), _ right: (date: Date, order: OrderHeader)) -> Bool {
  left.date > right.date
}

func orderScreen(from v: Order, pk: String, dID: String) -> OrderScreen.State {
  let orderNote: String
  let noteFieldFocused: Bool
  
  let coordinate =  v.location
  let address = assignedVisitFullAddress(from: v)
  let metadata = assignedVisitMetadata(from: v)
  orderNote = v.orderNote?.rawValue.rawValue ?? ""
  noteFieldFocused = v.noteFieldFocused
  let status: OrderScreen.State.OrderStatus
  switch v.geotagSent {
  case .notSent:
    status = .notSent
  case .pickedUp:
    status = .pickedUp
  case let .entered(entry):
    status = .entered(DateFormatter.stringDate(entry))
  case let .visited(entry, exit):
    status = .visited("\(DateFormatter.stringDate(entry)) — \(DateFormatter.stringDate(exit))")
  case let .checkedOut(visited, checkedOutDate):
    status = .checkedOut(visited: visited.map(visitedString(_:)), completed: DateFormatter.stringDate(checkedOutDate))
  case let .cancelled(visited, cancelledDate):
    status = .canceled(visited: visited.map(visitedString(_:)), canceled: DateFormatter.stringDate(cancelledDate))
  }
  
  return .init(
    title: orderTitle(from: v),
    orderNote: orderNote,
    noteFieldFocused: noteFieldFocused,
    coordinate: coordinate,
    address: address,
    metadata: metadata,
    status: status,
    deviceID: dID,
    publishableKey: pk
  )
}

func visitedString(_ visited: Order.Geotag.Visited) -> String {
  switch visited {
  case let .entered(entry): return DateFormatter.stringDate(entry)
  case let .visited(entry, exit): return "\(DateFormatter.stringDate(entry)) — \(DateFormatter.stringDate(exit))"
  }
}

func orderTitle(from v: Order) -> String {
  switch v.address {
  case .none: return "Order @ \(DateFormatter.stringDate(v.createdAt))"
  case let .some(.both(s, _)),
       let .some(.this(s)): return s.rawValue.rawValue
  case let .some(.that(f)): return f.rawValue.rawValue
  }}

func assignedVisitFullAddress(from a: Order) -> String {
  switch a.address {
  case .none: return ""
  case let .some(.both(_, f)): return f.rawValue.rawValue
  case let .some(.this(s)): return s.rawValue.rawValue
  case let .some(.that(f)): return f.rawValue.rawValue
  }
}

func assignedVisitMetadata(from a: Order) -> [OrderScreen.State.Metadata] {
  a.metadata
    .map(identity)
    .sorted(by: \.key)
    .map { (name: Order.Name, contents: Order.Contents) in
    OrderScreen.State.Metadata(key: "\(name)", value: "\(contents)")
  }
}

extension Sequence {
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
    return sorted { a, b in
      return a[keyPath: keyPath] < b[keyPath: keyPath]
    }
  }
}

extension DateFormatter {
  static func stringDate(_ date: Date) -> String {
    let dateFormat = DateFormatter()
    dateFormat.locale = Locale(identifier: "en_US_POSIX")
    dateFormat.dateFormat = "h:mm a"
    return dateFormat.string(from: date)
  }
}

func mapOrders(from orders: Set<Order>) -> [MapOrder] {
  orders.map { MapOrder(id: $0.id.rawValue.rawValue, coordinate: $0.location, status: mapVisitStatus(from: $0.geotagSent)) }
}

func mapVisitStatus(from geotagSent: Order.Geotag) -> MapOrder.Status {
  switch geotagSent {
  case .notSent, .pickedUp: return .pending
  case .entered, .visited:  return .visited
  case .checkedOut:         return .completed
  case .cancelled:          return .canceled
  }
}

extension SignUpFormScreen.State.Focus {
  init(formFocus: SignUpState.FormFocus) {
    switch formFocus {
    case .name: self = .name
    case .email: self = .email
    case .password: self = .password
    }
  }
}

func verificationState(_ verification: SignUpState.Verification) -> SignUpVerificationScreen.State {
  func firstField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.first.rawValue)
    case let .entering(.some(.one(d)), _, _),
         let .entering(.some(.two(d, _)), _, _),
         let .entering(.some(.three(d, _, _)), _, _),
         let .entering(.some(.four(d, _, _, _)), _, _),
         let .entering(.some(.five(d, _, _, _, _)), _, _):
      return String(d.rawValue)
    default:
      return ""
    }
  }
  
  func secondField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.second.rawValue)
    case let .entering(.some(.two(_, d)), _, _),
         let .entering(.some(.three(_, d, _)), _, _),
         let .entering(.some(.four(_, d, _, _)), _, _),
         let .entering(.some(.five(_, d, _, _, _)), _, _):
      return String(d.rawValue)
    default:
      return ""
    }
  }
  
  func thirdField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.third.rawValue)
    case let .entering(.some(.three(_, _, d)), _, _),
         let .entering(.some(.four(_, _, d, _)), _, _),
         let .entering(.some(.five(_, _, d, _, _)), _, _):
      return String(d.rawValue)
    default:
      return ""
    }
  }
  
  func fourthField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.fourth.rawValue)
    case let .entering(.some(.four(_, _, _, d)), _, _),
         let .entering(.some(.five(_, _, _, d, _)), _, _):
      return String(d.rawValue)
    default:
      return ""
    }
  }
  
  func fifthField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.fifth.rawValue)
    case let .entering(.some(.five(_, _, _, _, d)), _, _):
      return String(d.rawValue)
    default:
      return ""
    }
  }
  
  func sixthField() -> String {
    switch verification {
    case let .entered(code, _):
      return String(code.sixth.rawValue)
    default:
      return ""
    }
  }
  
  func fieldInFocus() -> SignUpVerificationScreen.State.Focus {
    switch verification {
    case .entering(.none, .focused, _):
      return .first
    case .entering(.one, .focused, _):
      return .second
    case .entering(.two, .focused, _):
      return .third
    case .entering(.three, .focused, _):
      return .fourth
    case .entering(.four, .focused, _):
      return .fifth
    case .entering(.five, .focused, _),
         .entered(_, .notSent(.focused, _)):
      return .sixth
    case .entered(_, .inFlight),
         .entered(_, .notSent(.unfocused, _)),
         .entering(_, .unfocused, _):
      return .none
    }
  }
  
  func verifying() -> Bool {
    switch verification {
    case .entered(_, .inFlight):
      return true
    case .entered(_, .notSent),
         .entering(_, _, _):
      return false
    }
  }
  
  func error() -> String {
    switch verification {
    case let .entered(_, .notSent(_, .some(e))),
         let .entering(_, _, .some(e)):
      return e.rawValue.rawValue
    case .entered(_, .inFlight),
         .entered(_, .notSent(_, .none)),
         .entering(_, _, .none):
      return ""
    }
  }
  
  return .init(
    firstField: firstField(),
    secondField: secondField(),
    thirdField: thirdField(),
    fourthField: fourthField(),
    fifthField: fifthField(),
    sixthField: sixthField(),
    fieldInFocus: fieldInFocus(),
    verifying: verifying(),
    error: error()
  )
}


