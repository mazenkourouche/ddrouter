import Foundation
import DDRouter

struct ResponseModel: Decodable {
    let _id: String
    let en: String
    let author: String
}

enum TestEndpoint {
    case random
}

extension TestEndpoint: EndpointType {

    var baseURL: URL {
        return URL(string: "https://programming-quotes-api.herokuapp.com")!
    }

    var path: String {
        switch self {
        case .random:
            return "/quotes/random"
        }
    }

    var query: [String : String] {
        return [:]
    }

    var method: HTTPMethod {
        switch self {
        case .random:
            return .get
        }
    }

    var task: HTTPTask {
        switch self {
        case .random:
            return .request
        }
    }

    var headers: HTTPHeaders? {
        return [:]
    }
}
