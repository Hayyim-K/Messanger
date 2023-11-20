//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Hayyim on 28/09/2023.
//



import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        let notAllowedSimboles = "@.#$[]"
        var safeEmail = emailAddress
        for character in notAllowedSimboles {
            safeEmail = safeEmail.replacingOccurrences(of: String(character), with: "-")
        }
        return safeEmail
    }
    
    
    
    //    public func test() {
    //        database.child("foo").setValue(["something" : true])
    //
    //    }
}

// MARK: - Account Managment

extension DatabaseManager {
    
    public enum DatabaseError: Error {
        case failedToFetch
        case failedTo
    }
    
    public func userExists(
        with email: String,
        completion: @escaping (Bool) -> Void
    ) {
        let notAllowedSimboles = "@.#$[]"
        var safeEmail = email
        for character in notAllowedSimboles {
            safeEmail = safeEmail.replacingOccurrences(of: String(character), with: "-")
        }
        
        database.child(safeEmail).observeSingleEvent(of: .value) { dataSnapshot in
            guard let _ = dataSnapshot.value as? String else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Insert new user to Database
    
    public func insertUser(
        with user: ChatAppUser,
        completion: @escaping (Bool) -> Void
    ) {
        database.child(user.safeEmail).setValue([
            "firstName" : user.firstName,
            "lastName" : user.lastName
        ]) { error, _ in
            guard error == nil else {
                print("failed to write to dataBase")
                completion(false)
                return
            }
            
            /*
             user = [
                [
                    "name":
                    "safe_email":
                ],
                [
                    "name":
                    "safe_email":
                ]
             ]
             */
            
            self.database.child("users").observeSingleEvent(of: .value) { snapshot in
                
                if var usersCollection = snapshot.value as? [[String : String]] {
                    //append to user dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                    
                } else {
                    //create that array
                    let newCollection: [[String : String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail
                        ]
                    ]
                    self.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                    }
                }
            }
            
            
        }
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String : String]], Error>) -> Void) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String : String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
    
}

//MARK: - Sending nessages / conversations

extension DatabaseManager {
    
    /*
     conversation => [
         [
             "conversation_id": "someID-1234"
             "other_user_email":
             "latest_message": => {
                 "date": Date()
                 "latest_message": "massage"
                 "is_read": Bool
             }
         ],
     ]
     
     "someID-1234" {
         "messages": [
             {
                 "id": String,
                 "type": text, photo, video...
                 "content": String,
                 "date": Date,
                 "sender_email": String,
                 "isRead": Bool
             }
         ]
     }
     */
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else { return }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value) { snapshot in
            guard var userNode = snapshot.value as? [String : Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
                
            case .text(let messageText): message = messageText
            case .attributedText(_): break
            case .photo(_): break
            case .video(_): break
            case .location(_): break
            case .emoji(_): break
            case .audio(_): break
            case .contact(_): break
            case .linkPreview(_): break
            case .custom(_): break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            
            var newConversationData = [
                "id" : conversationID,
                "other_user_email" : otherUserEmail,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            
            ]
            
            if var conversations = userNode["conversations"] as? [[String : Any]] {
                // conversation array exists for current user
                // you should append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(
                        conversationID: conversationID,
                        firstMessage: firstMessage,
                        completion: completion
                    )
                }
            } else {
                // conversation array does NOT exist
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(
                        conversationID: conversationID,
                        firstMessage: firstMessage,
                        completion: completion
                        )
                    
                }
            }
        }
        
    }
    
    private func finishCreatingConversation(conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//            "id": String,
//            "type": text, photo, video...
//            "content": String,
//            "date": Date,
//            "sender_email": String,
//            "isRead": Bool
//        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        
        switch firstMessage.kind {
            
        case .text(let messageText): message = messageText
        case .attributedText(_): break
        case .photo(_): break
        case .video(_): break
        case .location(_): break
        case .emoji(_): break
        case .audio(_): break
        case .contact(_): break
        case .linkPreview(_): break
        case .custom(_): break
        }
        
//        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
//            completion(false)
//            return
//        }
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": "",
            "date": currentUserEmail,
            "sender_email": "",
            "is_read" : false
        ]
        
        let value = [
            "messages" : [
                collectionMessage
            ]
        ]
        
        database.child("\(conversationID)").setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
        }
            completion(true)
        }
        
        
    }
    
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
        
    }
    
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<String, Error>) -> Void) {
        
    }
    /// sends a message with target conversation and message
    public func sendMessage(to conversation: String, message: Message, competion: @escaping (Bool) -> Void) {
        
    }
}



struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        let notAllowedSimboles = "@.#$[]"
        var safeEmail = emailAddress
        for character in notAllowedSimboles {
            safeEmail = safeEmail.replacingOccurrences(of: String(character), with: "-")
        }
        return safeEmail
    }
    
    var profilePictureFileName: String {
        //        b2banalytica-gmail-com_profile_picture.png
        "\(safeEmail)_profile_picture.png"
    }
}
