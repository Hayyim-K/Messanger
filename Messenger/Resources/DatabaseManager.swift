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
    
//    public func test() {
//        database.child("foo").setValue(["something" : true])
//
//    }
}




// MARK: - Account Managment

extension DatabaseManager {
    
    public func userExists(
        with email: String,
        completion: @escaping ((Bool) -> Void)
    ) {
        let notAllowedSimboles = ".#$[]"
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
    
    public func insertUser(with user: ChatAppUser) {
        database.child(user.safeEmail).setValue([
            "firstName" : user.firstName,
            "lastName" : user.lastName
        ])
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail: String {
        let notAllowedSimboles = ".#$[]"
        var safeEmail = emailAddress
        for character in notAllowedSimboles {
            safeEmail = safeEmail.replacingOccurrences(of: String(character), with: "-")
        }
        return safeEmail
    }
//    let profilePictureURL: String
}
