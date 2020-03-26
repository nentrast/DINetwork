//
//  NetworkRouter.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 19.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public typealias NetworkRouterCompletion = (_ data: Data?,_ response: URLResponse?,_ error: Error?)->()
public typealias NetworkResult<T> = ((Result<T?, NetworkError>) -> Void)
public typealias Key = String


public enum NetworkResponseError: Error {
    case noData
    case authorizationError
    case badRequest
    case outdate
    case failed
}

public protocol NetworkRouter: class {
    associatedtype Endpoint: EndpointType
    func request(_ route: Endpoint,
                 completion: @escaping NetworkRouterCompletion)
    func request<T: Codable>(_ route: Endpoint,
                             objectType: T.Type,
                             completion: @escaping NetworkResult<T>)
    func multipartUpload<T: Codable>(data: [Key: MultipartData],
                                     route: Endpoint,
                                     objectType: T.Type,
                                     completion: @escaping NetworkResult<T>,
                                     progressHandler: ((Progress) -> Void)?)
    func cancel()
}


public class Router<Endpoint: EndpointType>: NSObject, NetworkRouter, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    
    private var task: URLSessionTask?
    
    private var progress: [URL : ((Progress) -> Void)?] = [:]
    private var downloadFinifhed: [URL : ((URL) -> Void)?] = [:]
    private var uploadTask: URLSessionDataTask?

    lazy var uploadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
        
    public func request(_ route: Endpoint,
                        completion: @escaping NetworkRouterCompletion) {
        let session = URLSession.shared
        do {
            let request = try route.asURLRequest()
            task = session.dataTask(with: request, completionHandler: { (data, urlResponse, error) in
                completion(data, urlResponse, error)
            })
        } catch {
            completion(nil, nil, error)
        }
        self.task?.resume()
    }
    
    public func request<T: Codable>(_ route: Endpoint,
                                    objectType: T.Type,
                                    completion: @escaping ((Result<T?, NetworkError>) -> Void)) {
        request(route) { (data, response, error) in
            
            if let response = response as? HTTPURLResponse {
                self.handleResponse(response, data: data, objectType: objectType, completion: completion)
            } else {
                // TODO: hanlde error
            }
        }
    }
    
    public func multipartUpload<T: Codable>(data: [Key: MultipartData],
                                            route: Endpoint,
                                            objectType: T.Type,
                                            completion: @escaping ((Result<T?, NetworkError>) -> Void),
                                            progressHandler: ((Progress) -> Void)?) {
        var request = try? route.asURLRequest()
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request?.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = NSMutableData()
        
        data.forEach { (key, value) in
            httpBody.append(convertFileData(fieldName: key,
                                            fileName: value.fileName,
                                            mimeType: value.type.name,
                                            fileData: value.data,
                                            using: boundary))
        }
        
        httpBody.appendString("--\(boundary)--")
        
        request?.httpBody = httpBody as Data
        
        uploadTask = uploadSession.dataTask(with: request!, completionHandler: {[weak self] (data, response, error) in
            if let response = response as? HTTPURLResponse {
                self?.handleResponse(response,
                                     data: data,
                                     objectType: objectType,
                                     completion: completion)
            } else {
                //TODO: handle
            }
        })
        
        self.progress[request!.url!] = { value in
            progressHandler?(value)
        }
        
        uploadTask?.resume()
    }
    
    public func cancel() {
        task?.cancel()
    }
    
    public func download(url: URL, progress: ((Progress) -> Void)?, comletion: @escaping (Result<URL, NetworkError>) -> Void) -> URLSessionDownloadTask {
        let task = uploadSession.downloadTask(with: url)
        self.progress[url] = {value in
            progress?(value)
        }
        task.resume()
        
        self.downloadFinifhed[url] = { url in
            comletion(.success(url))
        }
        return task
    }
    
    // MARK: Private
    
    private func convertFileData(fieldName: String,
                                 fileName: String,
                                 mimeType: String,
                                 fileData: Data,
                                 using boundary: String) -> Data {
        let data = NSMutableData()
        
        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendString("\r\n")
        
        return data as Data
    }
    
    fileprivate func handleResponse<T: Codable>(_ response: HTTPURLResponse,
                                                data: Data?,
                                                objectType: T.Type,
                                                completion: ((Result<T?, NetworkError>) -> Void) ) {
        let result = handleResponseStatus(response, data: data)
        switch result {
        case .success(let data):
            if let data = data {
                do {
                    let object = try JSONObjectDecoder.decode(type: objectType, data: data)
                    completion(.success(object))
                } catch {
                    completion(.failure(.decodigFailed))
                }
            } else {
                completion(.success(nil))
            }
        case .failure(let error):
            completion(.failure(NetworkError.response(error)))
        }
    }
    
    fileprivate func handleResponseStatus(_ response: HTTPURLResponse,
                                          data: Data?) -> Result<Data?, NetworkResponseError> {
        switch response.statusCode {
        case 200...299:
            return .success(data)
        case 401...500:
            return .failure(NetworkResponseError.authorizationError)
        case 501...500:
            return .failure(NetworkResponseError.badRequest)
        default:
            return .failure(NetworkResponseError.failed)
        }
    }
    
    // MARK: URLSessionDowloadDelegate
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let url = downloadTask.originalRequest?.url, let downloadFinished = downloadFinifhed[url]{
            downloadFinished?(location)
            progress[url] = nil
            downloadFinifhed[url] = nil
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let value: Float = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        let model = Progress(totalSize: totalBytesExpectedToWrite,
                             bytesRecived: bytesWritten,
                             bytesExpexted: totalBytesWritten,
                             percentDone: value)
        guard let url = downloadTask.originalRequest?.url, let progress = progress[url] else {
            return
        }
        
        progress?(model)
    }
    
    // MARK: URLSessionTaskDelegate
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didSendBodyData bytesSent: Int64,
                           totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64) {
        let value: Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        let model = Progress(totalSize: totalBytesSent,
                             bytesRecived: totalBytesSent,
                             bytesExpexted: totalBytesExpectedToSend,
                             percentDone: value)
        guard let url = task.originalRequest?.url, let progress = progress[url] else {
            return
        }
        
        progress?(model)
    }
    
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        guard let url = task.originalRequest?.url else {
            return
        }

        progress[url] = nil
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
