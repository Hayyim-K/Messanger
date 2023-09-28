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
}

// MARK: - Account Managment

extension DatabaseManager {
    
    public func userExists(
        with email: String,
        completion: @escaping ((Bool) -> Void)
    ) {
        database.child(email).observeSingleEvent(of: .value) { dataSnapshot in
            guard let _ = dataSnapshot.value as? String else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Insert new user to Database
    
    public func insertUser(with user: ChatAppUser) {
        database.child(user.emailAddress).setValue([
            "firstName" : user.firstName,
            "lastName" : user.lastName
        ])
    }
}

struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
//    let profilePictureURL: String
}
