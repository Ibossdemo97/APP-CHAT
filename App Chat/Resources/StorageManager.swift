//
//  StorageManager.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 27/04/2023.
//

import Foundation
import FirebaseStorage

final class StorageManeger {
    static let shared = StorageManeger()
    static let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    //Tải ảnh lên và hiển thị nó bằng url
    public func uploadProfileAvatar(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        StorageManeger.storage.child("image/\(fileName)").putData(data, metadata: nil, completion: { metadata, error in
            guard error == nil else {
                print("Tải ảnh lên không thành công")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            StorageManeger.storage.child("image/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else {
                    print("Lỗi tải url ảnh lên")
                    completion(.failure(StorageErrors.failedToGetDowwnloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("Tải lại url: \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    //Tải ảnh được gửi đi trong tin nhắn
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        StorageManeger.storage.child("message_image/\(fileName)").putData(data, metadata: nil, completion: { [weak self] metadata, error in
            guard error == nil else {
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            StorageManeger.storage.child("message_image/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else {
                    print("Lỗi tải url ảnh lên")
                    completion(.failure(StorageErrors.failedToGetDowwnloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("Tải lại url: \(urlString)")
                completion(.success(urlString))
            })
        })
    }
    
    //Tải video được gửi đi trong tin nhắn
//    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
//        StorageManeger.storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: { [weak self] metadata, error in
        public func uploadMessageVideo(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
            StorageManeger.storage.child("message_videos/\(fileName)").putData(data, metadata: nil, completion:  { metadata, error in
            guard error == nil else {
                print("Lỗi tải video lên: \(error!)")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            StorageManeger.storage.child("message_videos/\(fileName)").downloadURL(completion: { url,error in
                guard let url = url else {
                    print("Lỗi tải url video xuống")
                    completion(.failure(StorageErrors.failedToGetDowwnloadUrl))
                    return
                }
                let urlString = url.absoluteString
                print("Tải lại url: \(urlString)")
                completion(.success(urlString))
            })
        })
//        public func uploadMessageVideo(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
//        StorageManeger.storage.child("message_videos/\(fileName)").putData(data, metadata: nil, completion:  { metadata, error in
//                    if let error = error as NSError? {
//                        let errorCode = StorageErrorCode(rawValue: error.code)
//                        let errorMessage = error.localizedDescription
//                        print("🥶🥶🥶Lỗi tải lên video - Mã lỗi: \(errorCode!.rawValue) - \(errorMessage)")
//                    } else {
//                        print("🥶🥶🥶🥶Lỗi tải lên video: Lỗi không xác định")
//                    }
//                })
//        StorageManeger.storage.child("message_videos/\(fileName)").downloadURL(completion: { url,error in
//            guard let url = url else {
//                print("Lỗi tải url video xuống")
//                completion(.failure(StorageErrors.failedToGetDowwnloadUrl))
//                return
//            }
//            let urlString = url.absoluteString
//            print("Tải lại url: \(urlString)")
//            completion(.success(urlString))
//        })
    }
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDowwnloadUrl
    }
    public func downloadUrl(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let refernce = StorageManeger.storage.child(path)
        
        refernce.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDowwnloadUrl))
                return
            }
            completion(.success(url))
        })
    }
}
