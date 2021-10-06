import Foundation

public typealias Parameters = [String: Any]

enum ParameterEncoding {

    static func encode(
        urlRequest: inout URLRequest,
        bodyParameters: Encodable?,
        urlParameters: Parameters?,
        encodingType: EncodingType = .json) throws {

        if let urlParameters = urlParameters {
            guard let url = urlRequest.url else { throw NetworkError.encodingFailed }
            urlRequest.url = try ParameterEncoding.getEncodedURL(url: url, parameters: urlParameters)
        }

        if let bodyParameters = bodyParameters {
            switch encodingType {
            case .json:
                urlRequest.httpBody = try ParameterEncoding.getEncoded(encodable: bodyParameters)
            case .urlEncoding:
                urlRequest.httpBody = try ParameterEncoding.getURLEncoded(encodable: bodyParameters)
            }

        }
    }
    
    // encoding functions // todo: make these more similar
    private static func getEncoded(encodable: Encodable) throws -> Data {
        guard let encoded = try? JSONEncoder().encode(AnyEncodable(encodable)) else {
            throw NetworkError.encodingFailed
        }
        return encoded
    }

    private static func getURLEncoded(encodable: Encodable) throws -> Data {
        guard
            let encodableDictionary = try? encodable.asDictionary()
        else {
            throw NetworkError.encodingFailed
        }
        let urlEncoded = try encodableDictionary.map { (key, value) in
            guard let value = value as? String else {
                throw NetworkError.encodingFailed
            }
            return "\(key)=\(value)"
        }.joined(separator: "&").data(using: .utf8)
        guard let urlEncoded = urlEncoded else { throw NetworkError.encodingFailed }
        return urlEncoded
    }

    private static func getEncodedURL(url: URL, parameters: Parameters) throws -> URL {
        guard
            !parameters.isEmpty, // so what if they are? encode empty
            var urlComponents = URLComponents( // what does this do?
                url: url,
                resolvingAgainstBaseURL: false) else { throw NetworkError.encodingFailed }

        urlComponents.queryItems = parameters.map { key, value in
            return URLQueryItem(name: key, value: "\(value)")
        }

        guard let url = urlComponents.url else { throw NetworkError.encodingFailed }

        return url
    }
}

extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}
