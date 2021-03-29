import ComposableArchitecture
import NonEmpty
import Prelude
import Tagged
import Types


public typealias APIOrderID = Tagged<APIOrderIDTag, NonEmptyString>
public enum APIOrderIDTag {}

public enum APIError: Equatable, Error { case unknown }

public enum VisitStatus: Equatable {
  case entered(Date)
  case visited(Date, Date)
}

public struct APIOrder: Equatable {
  public enum Source: Equatable { case order, trip }
  
  public typealias Name     = Tagged<(APIOrder, name: ()),     NonEmptyString>
  public typealias Contents = Tagged<(APIOrder, contents: ()), NonEmptyString>
  
  public let centroid: Coordinate
  public let createdAt: Date
  public let metadata: [Name: Contents]
  public let source: Source
  public let visitStatus: VisitStatus?
  
  public init(
    centroid: Coordinate,
    createdAt: Date,
    metadata: [Name: Contents],
    source: Source,
    visited: VisitStatus?
  ) {
    self.centroid = centroid
    self.createdAt = createdAt
    self.metadata = metadata
    self.source = source
    self.visitStatus = visited
  }
}

public enum ResendVerificationResponse {
  case success
  case alreadyVerified
  case error(NonEmptyString)
}

public enum VerificationResponse: Equatable {
  case success(PublishableKey)
  case alreadyVerified
  case error(SignUpError)
}

public struct APIEnvironment {
  public var getHistory: (PublishableKey, DeviceID, Date) -> Effect<Result<History, APIError>, Never>
  public var getOrders: (PublishableKey, DeviceID) -> Effect<Result<[APIOrderID: APIOrder], APIError>, Never>
  public var resendVerificationCode: (Email) -> Effect<Result<ResendVerificationResponse, APIError>, Never>
  public var reverseGeocode: ([Coordinate]) -> Effect<[(Coordinate, These<Order.Street, Order.FullAddress>?)], Never>
  public var signIn: (Email, Password) -> Effect<Result<PublishableKey, APIError>, Never>
  public var signUp: (BusinessName, Email, Password, BusinessManages, ManagesFor) -> Effect<Result<SignUpError?, APIError>, Never>
  public var verifyEmail: (Email, VerificationCode) -> Effect<Result<VerificationResponse, APIError>, Never>
  
  public init(
    getHistory: @escaping (PublishableKey, DeviceID, Date) -> Effect<Result<History, APIError>, Never>,
    getOrders: @escaping (PublishableKey, DeviceID) -> Effect<Result<[APIOrderID: APIOrder], APIError>, Never>,
    resendVerificationCode: @escaping (Email) -> Effect<Result<ResendVerificationResponse, APIError>, Never>,
    reverseGeocode: @escaping ([Coordinate]) -> Effect<[(Coordinate, These<Order.Street, Order.FullAddress>?)], Never>,
    signIn: @escaping (Email, Password) -> Effect<Result<PublishableKey, APIError>, Never>,
    signUp: @escaping (BusinessName, Email, Password, BusinessManages, ManagesFor) -> Effect<Result<SignUpError?, APIError>, Never>,
    verifyEmail: @escaping (Email, VerificationCode) -> Effect<Result<VerificationResponse, APIError>, Never>
  ) {
    self.getHistory = getHistory
    self.getOrders = getOrders
    self.resendVerificationCode = resendVerificationCode
    self.reverseGeocode = reverseGeocode
    self.signIn = signIn
    self.signUp = signUp
    self.verifyEmail = verifyEmail
  }
}
