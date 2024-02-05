//
//  StorageManager.swift
//  Messenger
//
//  Created by Hayyim on 13/11/2023.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    
    public enum StorageErrors: Error {
        case failedToUpload
        case faildToGetDownloadUrl
    }
    
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    /*
     /image/b2banalytica-gmail-com_profile_picture.png
     */
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    
    public func downloadURL(for path: String, completion: @escaping UploadPictureCompletion) {
        let reference = storage.child(path)
        
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.faildToGetDownloadUrl))
                return
            }
            
            completion(.success(url.absoluteString))
        }
    }
    
    /// Upload picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(
        with data: Data,
        fileName: String,
        completion: @escaping UploadPictureCompletion
    ) {
        storage
            .child("image/\(fileName)")
            .putData(data, metadata: nil) { [weak self] metaData, error in
                
                guard let strongSelf = self else { return }
                
                guard error == nil else {
                    //failed
                    print("failed to upload data to firebase for picture")
                    completion(.failure(StorageErrors.failedToUpload))
                    return
                }
                
                strongSelf.storage.child("image/\(fileName)").downloadURL { url, error in
                    guard let url = url else {
                        print("")
                        completion(.failure(StorageErrors.faildToGetDownloadUrl))
                        return
                    }
                    let urlString = url.absoluteString
                    print("Download url returned: \(urlString)")
                    completion(.success(urlString))
                }
            }
    }
    
    /// Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(
        with data: Data,
        fileName: String,
        completion: @escaping UploadPictureCompletion
    ) {
        storage
            .child("message_images/\(fileName)")
            .putData(data, metadata: nil) { [weak self] metaData, error in
                guard error == nil else {
                    //failed
                    print("failed to upload data to firebase for picture")
                    completion(.failure(StorageErrors.failedToUpload))
                    return
                }
                
                self?
                    .storage
                    .child("message_images/\(fileName)")
                    .downloadURL { url, error in
                        guard let url = url else {
                            print("")
                            completion(.failure(StorageErrors.faildToGetDownloadUrl))
                            return
                        }
                        
                        let urlString = url.absoluteString
                        print("Download url returned: \(urlString)")
                        completion(.success(urlString))
                    }
            }
    }
    
    /// Upload video that will be sent in a conversation message
    public func uploadMessageVideo(
        with fileURL: URL,
        fileName: String,
        completion: @escaping UploadPictureCompletion
    ) {
        storage
            .child("message_videos/\(fileName)")
            .putFile(from: fileURL) { [weak self] metaData, error in
                guard error == nil else {
                    //failed
                    print("failed to upload video File to firebase for picture")
                    completion(.failure(StorageErrors.failedToUpload))
                    return
                }
                
                self?
                    .storage
                    .child("message_videos/\(fileName)")
                    .downloadURL { url, error in
                        guard let url = url else {
                            print("!!!!*&#^$*&#^$@")
                            completion(.failure(StorageErrors.faildToGetDownloadUrl))
                            return
                        }
                        
                        let urlString = url.absoluteString
                        print("Download url returned: \(urlString)")
                        completion(.success(urlString))
                    }
            }
    }
    
}
