//
//  ChatViewController.swift
//  Messenger
//
//  Created by Hayyim on 10/11/2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation
import Photos
import PhotosUI


struct Message: MessageType {
    
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
    
}

extension MessageKind {
    var messageKindString: String {
        switch self {
            
        case .text(_): "text"
        case .attributedText(_): "attributed_text"
        case .photo(_): "photo"
        case .video(_): "video"
        case .location(_): "location"
        case .emoji(_): "emoji"
        case .audio(_): "audio"
        case .contact(_): "contact"
        case .linkPreview(_): "link_preview"
        case .custom(_): "custom"
        }
    }
}

struct Sender: SenderType {
    
    public var photoURL: String
    public var displayName: String
    public var senderId: String
    
}

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
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
    
    private var conversationID: String?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String
        else { return nil }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: (email))
        
        return Sender(
            photoURL: "",
            displayName: "Me",
            senderId: safeEmail
        )
    }
    
    private var senderPhotoURL: URL?
    private var recipientPhotoURL: URL?
    
    
    init(with email: String, id: String?) {
        self.conversationID = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        //        if let conversationID = conversationID {
        //            listenForMessages(id: conversationID, shouldScrollToBottom: true)
        //        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        
        view.backgroundColor = .red
        //        messagesCollectionView.reloadData()
        setupInputButton()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationID = conversationID {
            listenForMessages(id: conversationID, shouldScrollToBottom: true)
        }
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: true)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: true)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: true)
        
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(
            title: "Attach Media",
            message: "What would you like to attach?",
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(
            UIAlertAction(
                title: "Photo",
                style: .default,
                handler: { [weak self] _ in
                    self?.presentPhotoInputActionSheet()
                }
            )
        )
        actionSheet.addAction(
            UIAlertAction(
                title: "Video",
                style: .default,
                handler: { [weak self] _ in
                    self?.presentVideoInputActionSheet()
                }
            )
        )
        actionSheet.addAction(
            UIAlertAction(
                title: "Audio",
                style: .default,
                handler: { _ in
                    
                }
            )
        )
        actionSheet.addAction(
            UIAlertAction(
                title: "Location",
                style: .default,
                handler: { [weak self] _ in
                    self?.presentLocationPicker()
                }
            )
        )
        actionSheet.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )
        
        present(actionSheet, animated: true)
        
    }
    
    private func presentPhotoInputActionSheet() {
        
        let actionSheet = UIAlertController(
            title: "Attach Photo",
            message: "Where would you like to attach a photo from?",
            preferredStyle: .actionSheet
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Camera",
                style: .default,
                handler: { [weak self] _ in
                    let picker = UIImagePickerController()
                    picker.sourceType = .camera
                    picker.delegate = self
                    picker.allowsEditing = true
                    self?.present(picker, animated: true)
                }
            )
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Photo Library",
                style: .default,
                handler: { [weak self] _ in
                    let picker = UIImagePickerController()
                    picker.sourceType = .photoLibrary
                    picker.delegate = self
                    picker.allowsEditing = true
                    self?.present(picker, animated: true)
                }
            )
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        
        let actionSheet = UIAlertController(
            title: "Attach Video",
            message: "Where would you like to attach a video from?",
            preferredStyle: .actionSheet
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Camera",
                style: .default,
                handler: { [weak self] _ in
                    let picker = UIImagePickerController()
                    picker.sourceType = .camera
                    picker.delegate = self
                    picker.mediaTypes = ["public.movie"]
                    picker.videoQuality = .typeMedium
                    picker.allowsEditing = true
                    self?.present(picker, animated: true)
                }
            )
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Library",
                style: .default,
                handler: { [weak self] _ in
                    
                    self?.showVideoPicker()
                    //                    var configuration = PHPickerConfiguration()
                    //                    configuration.filter = .videos
                    //                    let picker = PHPickerViewController(configuration: configuration)
                    //                    picker.delegate = self
                    
                    //                    let picker = UIImagePickerController()
                    //                    picker.sourceType = .photoLibrary
                    //                    picker.delegate = self
                    //                    picker.allowsEditing = true
                    //                    picker.mediaTypes = ["public.movie"]
                    //                    picker.videoQuality = .typeMedium
                    
                    //                    self?.present(picker, animated: true)
                }
            )
        )
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        
        guard let messageId = createMessageId(),
              let conversationID = conversationID,
              let name = self.title,
              let selfSender = selfSender
        else { return }
        
        let vc = LocationPickerViewController(coordinates: nil)
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.title = "Pick Location"
        vc.completion = { [weak self] selectedCoordinates in
            
            guard let strongSelf = self else { return }
            
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            print("long = \(longitude), lat = \(latitude)")
            
            let location = Location(
                location: CLLocation(
                    latitude: latitude,
                    longitude: longitude
                ),
                size: .zero
            )
            
            let message = Message(
                sender: selfSender,
                messageId: messageId,
                sentDate: Date(),
                kind: .location(location)
            )
            
            DatabaseManager.shared.sendMessage(
                to: conversationID,
                otherUserEmail: strongSelf.otherUserEmail,
                name: name,
                newMessage: message) { success in
                    success ?
                    print("sent location message") :
                    print("failed to send location message")
                }
            
        }
        navigationController?.pushViewController(vc, animated: true)
        
    }
    
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager
            .shared
            .getAllMessagesForConversation(with: id) { [weak self] result in
                
                switch result {
                case .success(let messages):
                    
                    guard !messages.isEmpty else { return }
                    self?.messages = messages
                    
                    DispatchQueue.main.async {
                        
                        self?.messagesCollectionView.reloadDataAndKeepOffset()
                        
                        if shouldScrollToBottom {
                            self?.messagesCollectionView.scrollToLastItem()
                        }
                        
                        
                    }
                    
                case .failure(let error):
                    print("failed to get messages: \(error)")
                }
            }
    }
    
}

extension ChatViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
        picker.dismiss(animated: true)
        
        if let itemProvider = results.first?.itemProvider {
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                
                //set it if move imagePicker to PHPickerVC
                
//                itemProvider.loadObject(
//                    ofClass: UIImage.self) { [weak self] image, error in
//                        if let error {
//                            print("ERROR\n\(error)")
//                        } else {
//                            DispatchQueue.main.async {
//                                self?.upload(data: image as! UIImage)
//                            }
//                        }
//                    }
            } else if itemProvider
                .hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                itemProvider
                    .loadFileRepresentation(
                        forTypeIdentifier: UTType.movie.identifier
                    ) { [weak self] url, error in
                        do {
                            guard let url = url else {
                                throw error ?? NSError(domain: NSFileProviderErrorDomain, code: -1)
                            }
                            let localURL = FileManager
                                .default
                                .temporaryDirectory
                                .appendingPathComponent(url.lastPathComponent)
                            try? FileManager.default.removeItem(at: localURL)
                            try FileManager.default.copyItem(at: url, to: localURL)
                            DispatchQueue.main.async {
                                self?.upload(data: localURL)
                            }
                        } catch let catchedError {
                            print("ERROR _______CATCHED")
                            print(catchedError)
                        }
                        
                    }
            }
        }
        
        
    }
    
    private func upload(data: Any) {
        
        guard let messageId = createMessageId(),
              let conversationID = conversationID,
              let name = self.title,
              let selfSender = selfSender
        else { return }
        
        if let image = data as? UIImage,
           let imageData = image.pngData() {
            
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // Upload image
            StorageManager.shared.uploadMessagePhoto(
                with: imageData,
                fileName: fileName) { [weak self] result in
                    
                    guard let strongSelf = self else { return }
                    
                    switch result {
                    case .success(let urlString):
                        //Ready to send message
                        
                        print("Uploaded Message Photo: \(urlString)")
                        
                        guard let url = URL(string: urlString),
                              let placeholder = UIImage(systemName: "plus")
                        else { return }
                        
                        let media = Media(
                            url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero
                        )
                        
                        let message = Message(
                            sender: selfSender,
                            messageId: messageId,
                            sentDate: Date(),
                            kind: .photo(media)
                        )
                        
                        DatabaseManager.shared.sendMessage(
                            to: conversationID,
                            otherUserEmail: strongSelf.otherUserEmail,
                            name: name,
                            newMessage: message) { success in
                                success ?
                                print("sent photo message") :
                                print("failed to send photo message")
                            }
                        
                    case .failure(let error):
                        print("message photo upload error: \(error)")
                    }
                }
            
            
        } else if let videoURL = data as? URL {
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            // Upload Video
            StorageManager.shared.uploadMessageVideo(
                with: videoURL,
                fileName: fileName) { [weak self] result in
                    
                    guard let strongSelf = self else { return }
                    
                    switch result {
                    case .success(let urlString):
                        //Ready to send message
                        
                        print("Uploaded Message Video: \(urlString)")
                        
                        guard let url = URL(string: urlString),
                              let placeholder = UIImage(systemName: "plus")
                        else { return }
                        
                        let media = Media(
                            url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero
                        )
                        
                        let message = Message(
                            sender: selfSender,
                            messageId: messageId,
                            sentDate: Date(),
                            kind: .video(media)
                        )
                        
                        DatabaseManager.shared.sendMessage(
                            to: conversationID,
                            otherUserEmail: strongSelf.otherUserEmail,
                            name: name,
                            newMessage: message) { success in
                                success ?
                                print("sent video message") :
                                print("failed to send video message")
                            }
                        
                    case .failure(let error):
                        print("message video upload error: \(error)")
                    }
                }
        }
    }
    
    private func showVideoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        
        present(picker, animated: true)
    }
    
//    private func showCamera() {
//        var configuration = UIImagePickerController()
//        
//        configuration.filter = .videos
//        
//        let picker = PHPickerViewController(configuration: configuration)
//        picker.delegate = self
//        
//        present(picker, animated: true)
//    }
    
    
}


extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationID = conversationID,
              let name = self.title,
              let selfSender = selfSender
        else { return }
        
        if let image = info[.editedImage] as? UIImage,
           let imageData = image.pngData() {
            
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            // Upload image
            StorageManager.shared.uploadMessagePhoto(
                with: imageData,
                fileName: fileName) { [weak self] result in
                    
                    guard let strongSelf = self else { return }
                    
                    switch result {
                    case .success(let urlString):
                        //Ready to send message
                        
                        print("Uploaded Message Photo: \(urlString)")
                        
                        guard let url = URL(string: urlString),
                              let placeholder = UIImage(systemName: "plus")
                        else { return }
                        
                        let media = Media(
                            url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero
                        )
                        
                        let message = Message(
                            sender: selfSender,
                            messageId: messageId,
                            sentDate: Date(),
                            kind: .photo(media)
                        )
                        
                        DatabaseManager.shared.sendMessage(
                            to: conversationID,
                            otherUserEmail: strongSelf.otherUserEmail,
                            name: name,
                            newMessage: message) { success in
                                success ?
                                print("sent photo message") :
                                print("failed to send photo message")
                            }
                        
                    case .failure(let error):
                        print("message photo upload error: \(error)")
                    }
                }
            
            
        }
        else if let videoURL = info[.mediaURL] as? URL {
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            // Upload Video
            StorageManager.shared.uploadMessageVideo(
                with: videoURL,
                fileName: fileName) { [weak self] result in
                    
                    guard let strongSelf = self else { return }
                    
                    switch result {
                    case .success(let urlString):
                        //Ready to send message
                        
                        print("Uploaded Message Video: \(urlString)")
                        
                        guard let url = URL(string: urlString),
                              let placeholder = UIImage(systemName: "plus")
                        else { return }
                        
                        let media = Media(
                            url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero
                        )
                        
                        let message = Message(
                            sender: selfSender,
                            messageId: messageId,
                            sentDate: Date(),
                            kind: .video(media)
                        )
                        
                        DatabaseManager.shared.sendMessage(
                            to: conversationID,
                            otherUserEmail: strongSelf.otherUserEmail,
                            name: name,
                            newMessage: message) { success in
                                success ?
                                print("sent video message") :
                                print("failed to send video message")
                            }
                        
                    case .failure(let error):
                        print("message video upload error: \(error)")
                    }
                }
        }
        
    }
    
}


extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(
        _ inputBar: InputBarAccessoryView,
        didPressSendButtonWith text: String
    ) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId()
        else { return }
        
        let message = Message(
            sender: selfSender,
            messageId: messageId,
            sentDate: Date(),
            kind: .text(text)
        )
        // Send Message
        if isNewConversation {
            
            print(otherUserEmail)
            //create convo in dataBase
            DatabaseManager.shared.createNewConversation(
                with: otherUserEmail,
                name: self.title ?? "User",
                firstMessage: message) { [weak self] success in
                    if success {
                        print("message sent")
                        self?.isNewConversation = false
                        let newConversationID = "conversation_\(message.messageId)"
                        self?.conversationID = newConversationID
                        self?.listenForMessages(
                            id: newConversationID,
                            shouldScrollToBottom: true
                        )
                        // clear input view after sending
                        self?.messageInputBar.inputTextView.text = nil
                    } else {
                        print("failed to send")
                    }
                }
        } else {
            
            //append to existing conversation data
            guard let conversationID = conversationID,
                  let name = self.title
            else { return }
            
            DatabaseManager.shared.sendMessage(
                to: conversationID,
                otherUserEmail: otherUserEmail,
                name: name,
                newMessage: message) { [weak self] success in
                    if success {
                        self?.messageInputBar.inputTextView.text = nil
                        print("Message sent")
                    } else {
                        print("Failed to send")
                    }
                }
            
        }
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        
        guard let currentUserEmail = UserDefaults
            .standard
            .value(forKey: "email") as? String
        else { return nil }
        
        let safeCurrentEmail = DatabaseManager
            .safeEmail(emailAddress: currentUserEmail)
        
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
    }
    
    func messageForItem(
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(
        in messagesCollectionView: MessagesCollectionView
    ) -> Int {
        messages.count
    }
    
    func configureMediaMessageImageView(
        _ imageView: UIImageView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        guard let message = message as? Message else { return }
        
        switch message.kind {
        case .photo(let media):
            guard let imageURL = media.url else { return }
            imageView.sd_setImage(with: imageURL)
        default:
            break
        }
    }
    
    //    func collectionView(
    //        _ collectionView: UICollectionView,
    //        didSelectItemAt indexPath: IndexPath
    //    ) {
    //        let message = messages[indexPath.section]
    //
    //        switch message.kind {
    //
    //        case .photo(let media):
    //
    //            guard let imageURL = media.url else { return }
    //
    //            let vc = PhotoViewerViewController(with: imageURL)
    //            self.navigationController?.pushViewController(vc, animated: true)
    //
    //        default:
    //            break
    //        }
    //    }
    
    //messages' background Color
    func backgroundColor(
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            return .orange
        }
        return .purple
    }
    
    // avatars setting
    func configureAvatarView(
        _ avatarView: AvatarView,
        for message: MessageType,
        at indexPath: IndexPath,
        in messagesCollectionView: MessagesCollectionView
    ) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            if let currentUserImageURL = senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL)
            } else {
                // image/safeEmail_profile_picture.png
                guard let email = UserDefaults.standard.value(forKey: "email") as? String
                else { return }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "image/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        if let url = URL(string: url) {
                            self?.senderPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url)
                            }
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        } else {
            if let otherUserPhotoURL = recipientPhotoURL {
                avatarView.sd_setImage(with: otherUserPhotoURL)
            } else {
                let email = otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "image/\(safeEmail)_profile_picture.png"
                StorageManager.shared.downloadURL(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        if let url = URL(string: url) {
                            self?.recipientPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url)
                            }
                        }
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        }
    }
    
    
    
}

extension ChatViewController: MessageCellDelegate {
    
    //    func didTapBackground(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    func didTapMessage(in cell: MessageKit.MessageCollectionViewCell) {
        
        guard let indexPath = messagesCollectionView.indexPath(for: cell)
        else { return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .location (let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            
            self.navigationController?.pushViewController(vc, animated: true)
            
        default:
            break
        }
    }
    //
    //    func didTapAvatar(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    //    func didTapCellTopLabel(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    //    func didTapCellBottomLabel(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    //    func didTapMessageTopLabel(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    //    func didTapMessageBottomLabel(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    //
    //    func didTapAccessoryView(in cell: MessageKit.MessageCollectionViewCell) {
    //
    //    }
    
    func didTapImage(in cell: MessageKit.MessageCollectionViewCell) {
        
        guard let indexPath = messagesCollectionView.indexPath(for: cell)
        else { return }
        
        let message = messages[indexPath.section]
        
        switch message.kind {
            
        case .photo(let media):
            guard let imageURL = media.url else { return }
            
            let vc = PhotoViewerViewController(with: imageURL)
            self.navigationController?.pushViewController(vc, animated: true)
            
        case .video(let media):
            guard let videoURL = media.url else { return }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoURL)
            present(vc, animated: true)
            
        default:
            break
        }
    }
    
    //        func didTapPlayButton(in cell: MessageKit.AudioMessageCell) {
    //
    //        }
    //
    //    func didStartAudio(in cell: MessageKit.AudioMessageCell) {
    //
    //    }
    //
    //    func didPauseAudio(in cell: MessageKit.AudioMessageCell) {
    //
    //    }
    //
    //    func didStopAudio(in cell: MessageKit.AudioMessageCell) {
    //
    //    }
    
}

