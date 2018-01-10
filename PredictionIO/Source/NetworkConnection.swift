//
//  NetworkConnection.swift
//  PredictionIO
//
//  Created by Minh Tu Le on 1/1/18.
//  Copyright © 2018 PredictionIO. All rights reserved.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

typealias HTTPHeaders = [String: String]
typealias QueryParams = [String: String]

class NetworkConnection {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    @discardableResult
    func get(url: String, queryParams: QueryParams? = nil, headers: HTTPHeaders? = nil, completionHandler: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask? {
        return request(url, method: .get, queryParams: queryParams, payload: nil, headers: headers, completionHandler: completionHandler)
    }

    @discardableResult
    func post(url: String, payload: Any?, queryParams: QueryParams? = nil, headers: HTTPHeaders? = nil, completionHandler: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask? {
        return request(url, method: .post, queryParams: queryParams, payload: payload, headers: headers, completionHandler: completionHandler)
    }

    @discardableResult
    func delete(url: String, queryParams: QueryParams? = nil, headers: HTTPHeaders? = nil, completionHandler: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask? {
        return request(url, method: .delete, queryParams: queryParams, payload: nil, headers: headers, completionHandler: completionHandler)
    }

    private func request(_ url: String, method: HTTPMethod, queryParams: QueryParams? = nil, payload: Any?, headers: HTTPHeaders? = nil, completionHandler: @escaping (Data?, Error?) -> Void) -> URLSessionDataTask? {
        do {
            var request = try URLRequest(url: url, method: method, queryParams: queryParams, headers: headers)
            try request.attachJSONPayload(payload: payload)

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completionHandler(nil, PIOError.RequestFailureReason.failedError(error))
                    return
                }

                guard let response = response as? HTTPURLResponse else {
                    completionHandler(nil, PIOError.RequestFailureReason.unknownResponseError())
                    return
                }

                switch response.statusCode {
                case 400:
                    completionHandler(nil, PIOError.RequestFailureReason.badRequestError())
                case 401:
                    completionHandler(nil, PIOError.RequestFailureReason.unauthorizedError())
                case 404:
                    completionHandler(nil, PIOError.RequestFailureReason.notFoundError())
                case 200...201:
                    completionHandler(data, nil)
                default:
                    // TODO: serialize payload to get the error message
                    completionHandler(nil, PIOError.RequestFailureReason.unknownStatusCodeError(statusCode: response.statusCode))
                }
            }
            task.resume()
            return task
        } catch {
            completionHandler(nil, error)
            return nil
        }
    }
}

extension URLRequest {
    init(url: String, method: HTTPMethod, queryParams: QueryParams? = nil, payload: Any? = nil, headers: HTTPHeaders? = nil) throws {
        var urlComponent = URLComponents(string: url)

        if let queryParams = queryParams {
            urlComponent?.queryItems = queryParams.map { URLQueryItem(name: $0, value: $1) }
        }

        guard let urlWithQuery = urlComponent?.url else {
            throw PIOError.invalidURL(string: url, queryParams: queryParams)
        }

        self.init(url: urlWithQuery)
        httpMethod = method.rawValue

        headers?.forEach { field, value in
            setValue(value, forHTTPHeaderField: field)
        }
    }

    mutating func attachJSONPayload(payload: Any?) throws {
        if let payload = payload,
            let httpMethod = httpMethod, httpMethod == HTTPMethod.post.rawValue {
            do {
                httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw PIOError.SerializationFailureReason.failedError(error)
            }
        }
    }
}
