//
//  ChatViewController.swift
//  Messenger
//
//  Created by Hayyim on 10/11/2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
    
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
    
}

extension MessageKind {
    var messageKindString: String {
        switch self {
            
        case .text(_):
            "text"
        case .attributedText(_):
            "attributed_text"
        case .photo(_):
            "photo"
        case .video(_):
            "video"
        case .location(_):
            "location"
        case .emoji(_):
            "emoji"
        case .audio(_):
            "audio"
        case .contact(_):
            "contact"
        case .linkPreview(_):
            "link_preview"
        case .custom(_):
            "custom"
        }
    }
}

struct Sender: SenderType {
    
    public var photoURL: String
    public var displayName: String
    public var senderId: String
    
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    public var isNewConversation = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") else {
            return nil
        }
        return Sender(
            photoURL: "",
            displayName: "Joe Smith",
            senderId: email as! String
        )
    }
    
    init(with email: String) {
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
        view.backgroundColor = .red
        messagesCollectionView.reloadData()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
}


extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else { return }
        
        print("""
    Sending: \(text)
""")
        
        // Send Message
        if isNewConversation {
            //create convo in dataBase
            let message = Message(
                sender: selfSender,
                messageId: messageId,
                sentDate: Date(),
                kind: .text(text)
            )
            
            DatabaseManager.shared.createNewConversation(
                with: otherUserEmail,
                firstMessage: message) { success in
                    if success {
                        print("message sent")
                    } else {
                        print("failed to send")
                    }
                }
        } else {
            //append to existing conversation data
            
        }
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdetifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("created massage ID: \(newIdetifier)")
        return newIdetifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesDisplayDelegate, MessagesLayoutDelegate {
    
    var currentSender: SenderType {
        if let sender = selfSender {
            return sender
        }
        
        fatalError("Self Sender is nil, email should be cached")
        
        return Sender(
            photoURL: "",
            displayName: "121",
            senderId: "   "
        )
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        messages.count
    }
    
}
