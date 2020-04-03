//
//  NetworkRouter.swift
//  DINetwork
//
//  Created by Alexandr Lobanov on 19.03.2020.
//  Copyright © 2020 Alexandr Lobanov. All rights reserved.
//

import Foundation

public typealias DINetworkRouterCompletion = (_ data: Data?,_ response: URLResponse?,_ error: Error?)->()
public typealias DINetworkResult<T> = ((Result<T?, DINetworkError>) -> Void)
public typealias Key = String


public enum DINetworkResponseError: Error {
    case noData
    case authorizationError
    case badRequest
    case outdate
    case failed
}

public protocol DINetworkRouter: class {
    associatedtype Endpoint: DIEndpointType
    func request(_ route: Endpoint,
                 completion: @escaping DINetworkRouterCompletion)
    func request<T: Codable>(_ route: Endpoint,
                             objectType: T.Type,
                             completion: @escaping DINetworkResult<T>)
    func multipartUpload<T: Codable>(data: [Key: DIMultipartData],
                                     route: Endpoint,
                                     objectType: T.Type,
                                     completion: @escaping DINetworkResult<T>,
                                     progressHandler: ((DIProgress) -> Void)?)
    func cancel()
}


public class DIRouter<Endpoint: DIEndpointType>: NSObject, DINetworkRouter, URLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    
    private var task: URLSessionTask?
    
    private var progress: [URL : ((DIProgress) -> Void)?] = [:]
    private var downloadFinifhed: [URL : ((URL) -> Void)?] = [:]
    private var uploadTask: URLSessionDataTask?

    lazy var uploadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()
    
//    init(cache: DICache<URL, Data>) {
//        
//    }
        
    public func request(_ route: Endpoint,
                        completion: @escaping DINetworkRouterCompletion) {
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
                                    completion: @escaping ((Result<T?, DINetworkError>) -> Void)) {
        request(route) { (data, response, error) in
            
            if let response = response as? HTTPURLResponse {
                self.handleResponse(response, data: data, objectType: objectType, completion: completion)
            } else {
                // TODO: hanlde error
            }
        }
    }
    
    public func multipartUpload<T: Codable>(data: [Key: DIMultipartData],
                                            route: Endpoint,
                                            objectType: T.Type,
                                            completion: @escaping ((Result<T?, DINetworkError>) -> Void),
                                            progressHandler: ((DIProgress) -> Void)?) {
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
        
    public func download(url: URL, resumedData: Data? = nil ,progress: ((DIProgress) -> Void)?, comletion: @escaping (Result<URL, DINetworkError>) -> Void) -> URLSessionDownloadTask {
        var task:  URLSessionDownloadTask!
        
        if let data = resumedData {
            task = uploadSession.downloadTask(withResumeData: data)
            
        } else {
            task  = uploadSession.downloadTask(with: url)
        }
        
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
                                                completion: ((Result<T?, DINetworkError>) -> Void) ) {
        let result = handleResponseStatus(response, data: data)
        switch result {
        case .success(let data):
            if let data = data {
                do {
                    let object = try DIJSONObjectDecoder.decode(type: objectType, data: data)
                    completion(.success(object))
                } catch {
                    completion(.failure(.decodigFailed))
                }
            } else {
                completion(.success(nil))
            }
        case .failure(let error):
            completion(.failure(DINetworkError.response(error)))
        }
    }
    
    fileprivate func handleResponseStatus(_ response: HTTPURLResponse,
                                          data: Data?) -> Result<Data?, DINetworkResponseError> {
        switch response.statusCode {
        case 200...299:
            return .success(data)
        case 401...500:
            return .failure(DINetworkResponseError.authorizationError)
        case 501...500:
            return .failure(DINetworkResponseError.badRequest)
        default:
            return .failure(DINetworkResponseError.failed)
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
        let model = DIProgress(totalSize: totalBytesExpectedToWrite,
                             bytesRecived: bytesWritten,
                             bytesExpexted: totalBytesWritten,
                             percentDone: value)
        
        guard let url = downloadTask.originalRequest?.url else {
            return
        }
        
        if downloadTask.state == .canceling {
            progress.removeValue(forKey: url)
            return
        }
        
        guard let progress = progress[url] else {
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
        let model = DIProgress(totalSize: totalBytesSent,
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
        weak var weakSeld = self

        weakSeld?.progress.removeValue(forKey: url)
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
