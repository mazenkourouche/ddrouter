import Foundation
import RxSwift

public class DDRouter {
    static var sharedSession: URLSession?
    static var printToConsole = false

    // must call this
    public static func initialise(
        configuration: URLSessionConfiguration,
        session: URLSession? = nil,
        printToConsole: Bool = false) {

        sharedSession = session ?? URLSession(configuration: configuration)
        Self.printToConsole = printToConsole
    }
}

public protocol RouterProtocol {
    associatedtype Endpoint: EndpointType
    associatedtype E: APIErrorModelProtocol
    func request<T: Decodable>(_ route: Endpoint) -> Single<T>
    init(ephemeralSession: Bool)
}

public struct EmptyStruct: Decodable {}

extension RouterProtocol {
    public typealias Empty = EmptyStruct
}

public class Router<Endpoint: EndpointType, E: APIErrorModelProtocol>: RouterProtocol {
    var urlSession: URLSession?

    required public init(ephemeralSession: Bool = false) {
        urlSession = ephemeralSession
            ? createEphemeralSession()
            : DDRouter.sharedSession
    }

    func createEphemeralSession() -> URLSession {
        // clone the current session config, then mutate as needed
        // what's the go with this not handling errors
        let ephemeralConfig = URLSessionConfiguration.ephemeral

        if let sharedConfig = DDRouter.sharedSession?.configuration {
            // copy separately protocol classes from current session config
            ephemeralConfig.protocolClasses = sharedConfig.protocolClasses
        }

        return URLSession(configuration: ephemeralConfig)
    }

    // todo: do this in the future
    // https://medium.com/@danielt1263/retrying-a-network-request-despite-having-an-invalid-token-b8b89340d29

    public func requestRaw(_ route: Endpoint) -> Single<Data> {

        return Single.create { [weak self] single in
            // bind self or return unknown error
            guard let self = self else {
                single(.error(APIError<E>.unknownError(nil)))
                return Disposables.create()
            }

            var task: URLSessionTask?

            // try to build the request
            let request: URLRequest
            do {
                request = try self.buildRequest(from: route)
            }
            catch let error {
                single(.error(error))
                return Disposables.create()
            }

            // log the request
            // todo: this should be a noop in prod / when disabled
            if DDRouter.printToConsole {
                NetworkLogger.log(request: request)
            }

            // get the session
            guard let urlSession = self.urlSession else {
                single(.error(APIError<E>.unknownError(nil)))
                return Disposables.create()
            }

            // perform the request
            task = urlSession.dataTask(with: request) { data, response, error in

                // return any error from the url session task - todo: wrap this error
                if let error = error {
                    single(.error(error))
                    return
                }

                // get the response body or throw null data error
                // todo: technically should throw different error if
                // first cast fails
                guard
                    let response = response as? HTTPURLResponse,
                    let responseData = data else {

                    single(.error(APIError<E>.nullData))
                    return
                }

                // print response
                if DDRouter.printToConsole {

                    // log response - todo: proper logging
                    NetworkLogger.log(response: response)

                    // print response data
                    Router.printJSONData(data: responseData)
                }

                // response switch
                switch response.statusCode {

                // 204 success with empty response
                case 204:
                    single(.success(responseData))

                // 2xx success.
                case 200...203, 205...299:

                    // just return, do the encoding elsewhere
                    single(.success(responseData))

                // 4xx client errors
                case 400...499:

                    // match the actual status code (or unknown error)
                    guard let statusCode = HTTPStatusCode(rawValue: response.statusCode) else {
                        single(.error(APIError<E>.unknownError(nil)))
                        return
                    }

                    switch statusCode {

                    // bad request
                    case .badRequest:
                        let error = try? JSONDecoder().decode(
                            E.self,
                            from: responseData)
                        single(.error(APIError<E>.badRequest(error)))

                    // unauthorized
                    case .unauthorized:
                        let error = try? JSONDecoder().decode(
                            E.self,
                            from: responseData)
                        single(.error(APIError<E>.unauthorized(error)))
                        return
                        // todo: add autoretry back, outside this function

                    // resource not found
                    case .notFound:
                        single(.error(APIError<E>.notFound))

                    // too many requests
                    case .tooManyRequests:
                        single(.error(APIError<E>.tooManyRequests))

                    // forbidden
                    case .forbidden:
                        let error = try? JSONDecoder().decode(
                            E.self,
                            from: responseData)
                        single(.error(APIError<E>.forbidden(error)))

                    // unknown
                    default:
                        let error = try? JSONDecoder().decode(
                            E.self,
                            from: responseData)

                        single(.error(APIError<E>.unknownError(error)))
                    }

                // 5xx server error
                case 500...599:

                    if
                        let statusCode = HTTPStatusCode(rawValue: response.statusCode),
                        statusCode == .serviceUnavailable {

                        single(.error(APIError<E>.serviceUnavailable))
                        return
                    }

                    let error = try? JSONDecoder().decode(
                        E.self,
                        from: responseData)
                    single(.error(APIError<E>.serverError(error)))

                // default / unknown error
                default:
                    let error = try? JSONDecoder().decode(
                        E.self,
                        from: responseData)

                    single(.error(APIError<E>.unknownError(error)))
                }
            }
            // make the request
            task?.resume()

            return Disposables.create {
                task?.cancel()
            }
        }
        .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
        .observeOn(MainScheduler.instance)
    }

    // this returns a single that will always subscribe on a background thread
    // and observe on the main thread
    public func request<T: Decodable>(_ route: Endpoint) -> Single<T> {

        return requestRaw(route)
            .map { responseData in

                // empty
                if let result = Empty() as? T {
                    return result
                }
                do {
                    // decode response
                    let decodedResponse = try JSONDecoder().decode(T.self, from: responseData)
                    return decodedResponse
                }
                catch (let error) {
                    throw APIError<E>.serializeError(error)
                }
            }
    }

    // build URLRequest from a given endpoint route
    private func buildRequest(from route: EndpointType) throws -> URLRequest {

        guard
            let urlSession = self.urlSession,
            var urlComponents = URLComponents(
                url: route.baseURL.appendingPathComponent(route.path),
                resolvingAgainstBaseURL: true) else {

            throw APIError<E>.internalError
        }

        // Build query
        if !route.query.isEmpty {
            let items = route.query.map { URLQueryItem(name: $0, value: $1) }
            urlComponents.queryItems = items
        }

        // get the url
        guard let url = urlComponents.url else {
            throw APIError<E>.internalError
        }

        // create a request
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: urlSession.configuration.timeoutIntervalForRequest)

        // method
        request.httpMethod = route.method.rawValue

        // headers
        if let additionalHeaders = route.headers {
            Router.addAdditionalHeaders(additionalHeaders, request: &request)
        }

        // content type
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // encode parameters
        switch route.task {
        case .request:
            break

        case .requestEncodableParameters(
            let bodyParameters,
            let urlParameters):

            do {
                try ParameterEncoding.encode(
                    urlRequest: &request,
                    bodyParameters: bodyParameters,
                    urlParameters: urlParameters)
            }
            catch let error {
                throw APIError<E>.serializeError(error)
            }
        }
        return request
    }

    private static func addAdditionalHeaders(
        _ additionalHeaders: HTTPHeaders?,
        request: inout URLRequest) {

        guard let headers = additionalHeaders else { return }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    // todo: move to NetworkLogger
    private static func printJSONData(data: Data) {

        guard
            let object = try? JSONSerialization.jsonObject(
                with: data,
                options: []),
            let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted]),
            let prettyPrintedString = NSString(
                data: data,
                encoding: String.Encoding.utf8.rawValue) else {

                // todo: consistent error logging
                print("----- Error in Json Response")
                return
        }

        print(prettyPrintedString)
    }
}
