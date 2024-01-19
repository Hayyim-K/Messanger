//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Hayyim on 28/09/2023.
//



import UIKit
import FirebaseDatabase
import MessageKit
import CoreLocation

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
    public func getDataFor(
        path: String,
        competion: @escaping (Result<Any, Error>) -> Void
    ) {
        self.database
            .child("\(path)")
            .observeSingleEvent(of: .value) { snapshot in
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
        //        let notAllowedSimboles = "@.#$[]"
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        //        for character in notAllowedSimboles {
        //            safeEmail = safeEmail.replacingOccurrences(of: String(character), with: "-")
        //        }
        
        database.child(safeEmail).observeSingleEvent(of: .value) { dataSnapshot in
            guard let _ = dataSnapshot.value as? [String : Any] else {
                
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
    
    public func getAllUsers(
        completion: @escaping (Result<[[String : String]], Error>) -> Void
    ) {
        database.child("users").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [[String : String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
    
}

//MARK: - Sending messages / conversations

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
              var currentName = UserDefaults.standard.value(forKey: "name") as? String
        else { return }

        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        database
            .child("\(safeEmail)")
            .observeSingleEvent(of: .value) { snapShot in
            guard let otherData = snapShot.value as? [String: Any]
            else { return }
            
            print("OTHERNAME")
            print(otherData)
            guard let currentFirstName = otherData["firstName"],
                  let currentLastName = otherData["lastName"]
            else { return }
            currentName = "\(currentFirstName) \(currentLastName)"
        }
        
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
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_): break
            case .photo(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
                break
            case .video(let mediaItem):
                if let targetURLString = mediaItem.url?.absoluteString {
                    message = targetURLString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
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
                            .setValue(conversations)
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
    
    
    
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(
        for email: String,
        completion: @escaping (Result<[Conversation], Error>) -> Void
    ) {
        database
            .child("\(email)/conversations")
            .observe(.value) { snapshot in
                guard let value = snapshot.value as? [[String : Any]]
                else {
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
    
    public func getAllMessagesForConversation(
        with id: String,
        completion: @escaping (Result<[Message], Error>) -> Void
    ) {
        
        
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let value = snapshot.value as? [[String : Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { [weak self] dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString),
                      let strongSelf = self
                else { return nil }
                
                let data: Any
                
                if let url = URL(string: content),
                   let placeholder = UIImage(systemName: type),
                   content.hasPrefix("http") {
                   
                    data = Media(
                        url: url,
                        image: nil,
                        placeholderImage: placeholder,
                        size: CGSize(width: 300, height: 300)
                    )
                } else {
                    data = content
                }
                
                let sender = Sender(
                    photoURL: "",
                    displayName: name,
                    senderId: senderEmail
                )
                
                return Message(
                    sender: sender,
                    messageId: messageID,
                    sentDate: date,
                    kind: strongSelf.getMessageKind(from: data, for: type)
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
        
        var currentName = name
        
        database
            .child("\(currentEmail)")
            .observeSingleEvent(of: .value) { snapShot in
            guard let otherData = snapShot.value as? [String: Any]
            else { return }
            
            print("OTHERNAME")
            print(otherData)
            guard let currentFirstName = otherData["firstName"],
                  let currentLastName = otherData["lastName"]
            else { return }
            currentName = "\(currentFirstName) \(currentLastName)"
        }
        
        
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
                    
                case .text(let messageText):
                    message = messageText
                case .attributedText(_):
                    break
                case .photo(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                    break
                case .video(let mediaItem):
                    if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                    }
                    break
                case .location(let locationData):
                    let location = locationData.location
                    message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                    break
                case .emoji(_): break
                case .audio(_): break
                case .contact(_): break
                case .linkPreview(_): break
                case .custom(_): break
                }
                
                //                guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String
                //                else {
                //                    competion(false)
                //                    return
                //                }
                
                //                let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
                
                let newMessageEntry: [String: Any] = [
                    "id": newMessage.messageId,
                    "type": newMessage.kind.messageKindString,
                    "content": message,
                    "date": dateString,
                    "sender_email": currentEmail,
                    "is_read" : false,
                    "name" : name
                ]
                
                currentMessages.append(newMessageEntry)
    //1)
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
                print("""
   //1
    from: \(currentEmail)
    currentName: \(currentName)
    name: \(name)
    to: \(otherUserEmail)
""")
                
                let updatedValue: [String : Any] = [
                    "date": dateString,
                    "is_read": false,
                    "message": message
                ]
    //2.1)
                strongSelf
                    .database
                    .child("\(currentEmail)/conversations")
                    .observeSingleEvent(of: .value) { snapshot in
                        
                        var conversationData: [[String : Any]]
                        
                        if var currentUserConversations = snapshot.value as? [[String : Any]] {
                            print("""
               //2.1
            message exists
            
            """)
                            //                        else {
                            //                            competion(false)
                            //                            return
                            //                        }
                            
                            //                            let updatedValue: [String : Any] = [
                            //                                "date": dateString,
                            //                                "is_read": false,
                            //                                "message": message
                            //                            ]
                            
                            //IF IT doesn't WORK - Part 17 39:00
                            
                            for index in 0..<currentUserConversations.count {
                                if let currentID = currentUserConversations[index]["id"] as? String,
                                   currentID == conversation {
                                    currentUserConversations[index]["latest_message"] = updatedValue
                                    currentUserConversations[index]["name"] = name
                                    //FROM HERE! !!
                                }
                            }
                            // to HERE !!!
                            
                            conversationData = currentUserConversations
                            //                            strongSelf
                            //                                .database
                            //                                .child("\(currentEmail)/conversations")
                            //                                .setValue(currentUserConversations) { error, _ in
                            //                                    guard error == nil else {
                            //                                        competion(false)
                            //                                        return
                            //                                    }
                            //                                    competion(true)
                            //                                }
                        } else {
    //2.2)
                            print("""
               //2.2
                        message doesnt exist
            """)
                            // CREATE CONVERSATION !!!
//                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String
//                            else { return }
//                            
//                            print("")
//                            print("currentName:")
//                            print(currentName)
//                            print("")
                            
//                            let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
                            
                            let newConversationData = [
                                [
                                    "id" : conversation,
                                    "other_user_email" : otherUserEmail,
                                    "name" : name,
                                    "latest_message" : [
                                        "date" : dateString,
                                        "message" : message,
                                        "is_read" : false
                                    ]
                                    
                                ]
                            ]
                            conversationData = newConversationData
                            //                            strongSelf
                            //                                .database
                            //                                .child("\(currentEmail)/conversations")
                            //                                .setValue(newConversationData) { error, _ in
                            //                                    guard error == nil else {
                            //                                        competion(false)
                            //                                        return
                            //                                    }
                            //                                    competion(true)
                            //                                }
                        }
 //3)
                        strongSelf
                            .database
                            .child("\(currentEmail)/conversations")
                            .setValue(conversationData) { error, _ in
                                guard error == nil else {
                                    competion(false)
                                    return
                                }
                                competion(true)
                            }
                        
                    }
                print("""
   //3
""")
    //4)
                // Update latest message for recipient user
                strongSelf
                    .database
                    .child("\(otherUserEmail)/conversations")
                    .observeSingleEvent(of: .value) { snapshot in
                        print("""
           //4
        """)
                        
                        
                        var conversationData: [[String : Any]]
                        
//                        guard let currentName = UserDefaults.standard.value(forKey: "name") as? String
//                        else { return }
   //4.1)
                        if var otherUserConversations = snapshot.value as? [[String : Any]] {
                            print("""
               //4.1
            recipient has a message
            """)
                            
                            
                            //                        else {
                            //                            competion(false)
                            //                            return
                            //                        }
                            
                            //                        let updatedValue: [String : Any] = [
                            //                            "date": dateString,
                            //                            "is_read": false,
                            //                            "message": message
                            //                        ]
                            
                            
                            
                            for index in 0..<otherUserConversations.count {
                                if let otherID = otherUserConversations[index]["id"] as? String,
                                   otherID == conversation {
                                    otherUserConversations[index]["latest_message"] = updatedValue
                                    otherUserConversations[index]["name"] = currentName
                                }
//
                            }
                            conversationData = otherUserConversations
//                            strongSelf
//                                .database
//                                .child("\(otherUserEmail)/conversations")
//                                .setValue(otherUserConversations) { error, _ in
//                                    guard error == nil else {
//                                        competion(false)
//                                        return
//                                    }
//                                    
//                                    competion(true)
//                                }
                            
                        } else {
                            print("""
               //4.2
                        recipient doesnt have a message
            """)
    //4.2)
                            // CREATE CONVERSATION !!!
                            
//                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String
//                            else { return }
//                            print("")
//                            print("currentName:")
//                            print(currentName)
//                            print("")
//                            let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
                            
                            let newConversationData = [
                                [
                                    "id" : conversation,
                                    "other_user_email" : currentEmail,
                                    "name" : currentName,
                                    "latest_message" : [
                                        "date" : dateString,
                                        "message" : message,
                                        "is_read" : false
                                    ]
                                    
                                ]
                            ]
                            //https://youtu.be/x6cMCAWu69A
//                            strongSelf
//                                .database
//                                .child("\(otherUserEmail)/conversations")
//                                .setValue(newConversationData) { error, _ in
//                                    guard error == nil else {
//                                        competion(false)
//                                        return
//                                    }
//                                    
//                                    competion(true)
//                                }
                            
                            conversationData = newConversationData
                        }
                        
                                                strongSelf
                                                    .database
                                                    .child("\(otherUserEmail)/conversations")
                                                    .setValue(conversationData) { error, _ in
                                                        guard error == nil else {
                                                            competion(false)
                                                            return
                                                        }
                        
                                                        competion(true)
                                                    }
                    }
            }
    }
    
    
    private func finishCreatingConversation(
        name: String,
        conversationID: String,
        firstMessage: Message,
        completion: @escaping (Bool) -> Void
    ) {
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
            
        case .text(let messageText):
            message = messageText
        case .attributedText(_): break
        case .photo(let mediaItem):
            if let targetURLString = mediaItem.url?.absoluteString {
                message = targetURLString
            }
            break
        case .video(let mediaItem):
            if let targetURLString = mediaItem.url?.absoluteString {
                message = targetURLString
            }
            break
        case .location(let locationData):
            let location = locationData.location
            message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
            break
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
    
    private func getMessageKind(from data: Any, for messageType: String) -> MessageKind {
        switch messageType {
        case "photo":
            return .photo(data as! MediaItem)
        case "video":
            return .video(data as! MediaItem)
        case "location":
            let locationString = data as! String
            let locationComponents = locationString.components(separatedBy: ",")
            
            guard let longitude = Double(locationComponents[0]),
                  let latitude = Double(locationComponents[1])
            else { fallthrough }
            
            let location = Location(
                location: CLLocation(
                    latitude: latitude,
                    longitude: longitude
                ),
                size: CGSize(width: 150, height: 150)
            )
            return .location(location)
        default:
            return .text(data as! String)
        }
    }
    
    public func deleteConversation(
        conversationID: String,
        comletion: @escaping (Bool) -> Void
    ) {
        guard let email = UserDefaults
            .standard
            .value(forKey: "email") as? String
        else { return }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        print("Deleting conversation with ID: \(conversationID)")
        
        // Get all conversations for current user
        //del conversation in collection with target id
        // reset those conversations for the user in database
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value) { snapshot in
            
            if var conversations = snapshot.value as? [[String: Any]] {
                
                for index in 0..<conversations.count {
                    if let id = conversations[index]["id"] as? String,
                       id == conversationID {
                        conversations.remove(at: index)
                    }
                }
                
                //                var positionToRemove = 0
                //                for conversation in conversations {
                //                    if let id = conversation["id"] as? String,
                //                       id == conversationID {
                //                        print("found conversation to delete")
                //                        break
                //                    }
                //                    positionToRemove += 1
                //                }
                //
                //                conversations.remove(at: positionToRemove)
                
                ref.setValue(conversations) { error, _ in
                    guard error == nil
                    else {
                        print("faield to write new conversation array")
                        comletion(false)
                        return
                    }
                    print("deleted conversation")
                    comletion(true)
                }
            }
        }
        
    }
    
    public func conversationExists(
        with targetRecipientEmail: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let safeRecipientEmail = DatabaseManager
            .safeEmail(emailAddress: targetRecipientEmail)
        
        guard let senderEmail = UserDefaults
            .standard
            .value(forKey: "email") as? String
        else { return }
        
        let safeSenderEmail = DatabaseManager
            .safeEmail(emailAddress: senderEmail)
        
        database
            .child("\(safeRecipientEmail)/conversations")
            .observeSingleEvent(of: .value) { dataSnapshot in
                guard let collection = dataSnapshot.value as? [[String : Any]]
                else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                
                //iterate and find conv with target sender
                if let conversation = collection.first(where: {
                    guard let targetSenderEmail = $0["other_user_email"] as? String
                    else { return false }
                    
                    return safeSenderEmail == targetSenderEmail
                }) {
                    // get id
                    guard let id = conversation["id"] as? String
                    else {
                        completion(.failure(DatabaseError.failedToFetch))
                        return
                    }
                    completion(.success(id))
                    return
                }
                completion(.failure(DatabaseError.failedToFetch))
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
