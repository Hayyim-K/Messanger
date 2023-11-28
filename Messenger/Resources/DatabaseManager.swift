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

extension DatabaseManager {
    public func getDataFor(path: String, competion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value else {
                competion(.failure(DatabaseError.failedToFetch))
                return
            }
            competion(.success(value))
        }
    }
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
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String
                
        else { return }
        
        
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
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
            
            let newConversationData = [
                "id" : conversationID,
                "other_user_email" : otherUserEmail,
                "name" : name,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
                
            ]
            
            let recipient_newConversationData = [
                "id" : conversationID,
                "other_user_email" : safeEmail,
                "name" : currentName,
                "latest_message" : [
                    "date" : dateString,
                    "message" : message,
                    "is_read" : false
                ]
            ]
            
            // Update recipient conversation entry
            
            self?
                .database
                .child("\(otherUserEmail)/conversations")
                .observeSingleEvent(of: .value) { [ weak self] snapshot in
                    
                    if var conversations = snapshot.value as? [[String : Any]] {
                        //append
                        conversations.append(recipient_newConversationData)
                        self?
                            .database
                            .child("\(otherUserEmail)/conversations")
                            .setValue(conversationID)
                    } else {
                        //create
                        self?
                            .database
                            .child("\(otherUserEmail)/conversations")
                            .setValue([recipient_newConversationData])
                    }
                }
            
            // Update current user conversation entry
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
                        name: name,
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
                        name: name,
                        conversationID: conversationID,
                        firstMessage: firstMessage,
                        completion: completion
                    )
                    
                }
            }
        }
        
    }
    
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
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
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read" : false,
            "name" : name
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
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("\(email)/conversations").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap { dictionary in
                guard let conversationID = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String : Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                let latestMessageObject = LatestMessage(
                    date: date,
                    text: message,
                    isRead: isRead
                )
                return Conversation(
                    id: conversationID,
                    name: name,
                    otherUserEmail: otherUserEmail,
                    latestMessage: latestMessageObject
                )
            }
            completion(.success(conversations))
        }
        
    }
    
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        
        
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString)
                else { return nil }
                
                let sender = Sender(
                    photoURL: "",
                    displayName: name,
                    senderId: senderEmail
                )
                
                return Message(
                    sender: sender,
                    messageId: messageID,
                    sentDate: date,
                    kind: .text(content)
                )
                
            }
            completion(.success(messages))
        }
        
        
    }
    /// sends a message with target conversation and message
    public func sendMessage(to conversation: String,
                            otherUserEmail: String,
                            name: String,
                            newMessage: Message,
                            competion: @escaping (Bool) -> Void) {
        
        // add new message to messages
        
        // update sender latest message
        
        //update recipient latest message
        
        guard let myEmail = UserDefaults
            .standard
            .value(forKey: "email") as? String else {
            competion(false)
            return
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database
            .child("\(conversation)/messages")
            .observeSingleEvent(of: .value) { [weak self] snapshot in
                guard let strongSelf = self else { return }
                guard var currentMessages = snapshot.value as? [[String : Any]]
                else {
                    competion(false)
                    return
                }
                
                let messageDate = newMessage.sentDate
                let dateString = ChatViewController.dateFormatter.string(from: messageDate)
                
                var message = ""
                
                switch newMessage.kind {
                    
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
                
                guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String
                else {
                    competion(false)
                    return
                }
                
                let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
                
                let newMessageEntry: [String: Any] = [
                    "id": newMessage.messageId,
                    "type": newMessage.kind.messageKindString,
                    "content": message,
                    "date": dateString,
                    "sender_email": currentUserEmail,
                    "is_read" : false,
                    "name" : name
                ]
                
                currentMessages.append(newMessageEntry)
                
                strongSelf
                    .database
                    .child("\(conversation)/messages")
                    .setValue(currentMessages) { error, _ in
                        guard error == nil
                        else {
                            competion(false)
                            return
                        }
                    }
                
                strongSelf
                    .database
                    .child("\(currentEmail)/conversations")
                    .observeSingleEvent(of: .value) { snapshot in
                        guard var currentUserConversations = snapshot.value as? [[String : Any]]
                        else {
                            competion(false)
                            return
                        }
                        
                        let updatedValue: [String : Any] = [
                            "date": dateString,
                            "is_read": false,
                            "message": message
                        ]
                        
                        for index in 0..<currentUserConversations.count {
                            if let currentID = currentUserConversations[index]["id"] as? String,
                               currentID == conversation {
                                currentUserConversations[index]["latest_message"] = updatedValue
                                strongSelf
                                    .database
                                    .child("\(currentEmail)/conversations")
                                    .setValue(currentUserConversations) { error, _ in
                                        guard error == nil else {
                                            competion(false)
                                            return
                                        }
                                        
                                        competion(true)
                                    }
                            }
                        }
                    }
                
                // Update latest message for recipient user
                strongSelf
                    .database
                    .child("\(otherUserEmail)/conversations")
                    .observeSingleEvent(of: .value) { snapshot in
                        guard var otherUserConversations = snapshot.value as? [[String : Any]]
                        else {
                            competion(false)
                            return
                        }
                        
                        let updatedValue: [String : Any] = [
                            "date": dateString,
                            "is_read": false,
                            "message": message
                        ]
                        
                        for index in 0..<otherUserConversations.count {
                            if let otherID = otherUserConversations[index]["id"] as? String,
                               otherID == conversation {
                                otherUserConversations[index]["latest_message"] = updatedValue
                                strongSelf
                                    .database
                                    .child("\(otherUserEmail)/conversations")
                                    .setValue(otherUserConversations) { error, _ in
                                        guard error == nil else {
                                            competion(false)
                                            return
                                        }
                                        
                                        competion(true)
                                    }
                            }
                        }
                    }
            }
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
