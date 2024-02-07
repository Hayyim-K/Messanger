//
//  ConversationsViewController.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Conversations!"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    private var conversations = [Conversation]()
    
    private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        
        return tableView
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .compose,
            target: self,
            action: #selector(didTapComposeButton)
        )
        
        //        view.backgroundColor = .red
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setUpTableView()
//        fetchConversations()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(
            forName: .didLogInNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                guard let strongSelf = self else { return }
                
                strongSelf.startListeningForConversations()
            }
        )
        
        //        DatabaseManager.shared.test()
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(
            x: 10,
            y: (view.height - 100) / 2,
            width: view.width - 20,
            height: 100
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
        tableView.reloadData()
    }
    
    private func startListeningForConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("starting conversation fetch... ")
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        DatabaseManager.shared.getAllConversations(
            for: safeEmail) { [weak self] result in
                switch result {
                case .success(let conversations) :
                    
                    print("successfully conversation models")
                    
                    
                    guard !conversations.isEmpty else {
                        self?.tableView.isHidden = false
                        self?.noConversationsLabel.isHidden = false
                        return
                    }
                    self?.noConversationsLabel.isHidden = true
                    self?.tableView.isHidden = false
                    self?.conversations = conversations
                    
                    DispatchQueue.main.async {
                        self?.tableView.reloadData()
                    }
                    
                case .failure(let error):
                    self?.tableView.isHidden = false
                    self?.noConversationsLabel.isHidden = false
                    print("faild to get convos: \(error)")
                    
                }
            }
    }
    
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LogInViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
    
    private func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
//    private func fetchConversations() {
//        tableView.isHidden = false
//    }
    
    private func createNewConversation(result: SearchResult) {
        
        let name = result.name
        let email = result.email
        
        // check in DB if conv with these two users exists
        // if it does, reuse conversation id
        // otherwise use existing code
        
        DatabaseManager.shared.conversationExists(
            with: email) { [weak self] result in
                guard let strongSelf = self
                else { return }
                switch result {
                case .success(let conversationID):
                    let vc = ChatViewController(with: email, id: conversationID)
                    vc.isNewConversation = false
                    vc.title = name
                    vc.navigationItem.largeTitleDisplayMode = .never
                    strongSelf
                        .navigationController?
                        .pushViewController(vc, animated: true)
                case .failure(_):
                    let vc = ChatViewController(with: email, id: nil)
                    vc.isNewConversation = true
                    vc.title = name
                    vc.navigationItem.largeTitleDisplayMode = .never
                    strongSelf
                        .navigationController?
                        .pushViewController(vc, animated: true)
                }
            }
        
        
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            
            guard let strongSelf = self
            else { return }
            
            let currentConversations = strongSelf.conversations
            
            if let targetConversation = currentConversations.first(where: {
                $0.otherUserEmail == DatabaseManager
                .safeEmail(emailAddress: result.email) }) {
                
                let vc = ChatViewController(
                    with: targetConversation.otherUserEmail,
                    id: targetConversation.id
                )
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf
                    .navigationController?
                    .pushViewController(vc, animated: true)
                
            } else {
                strongSelf.createNewConversation(result: result)
            }
            
            
        }
        
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        conversations.count
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let model = conversations[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationTableViewCell.identifier,
            for: indexPath
        ) as! ConversationTableViewCell
        
        cell.configure(with: model)
        
        //        var content = cell.defaultContentConfiguration()
        
        //        content.text = "Hello World"
        //
        //        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let model = conversations[indexPath.row]
        openConversation(model)
    }
    
    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        120
    }
    
    func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .delete
    }
    
    func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        if editingStyle == .delete {
            // begin delete
            let conversationID = conversations[indexPath.row].id
            
            tableView.beginUpdates()
            
            conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)
            
            DatabaseManager
                .shared
                .deleteConversation(
                    conversationID: conversationID
                ) { success in
                    if !success {
                        //add modeland row back show error alert
                        
//                        self?.conversations.remove(at: indexPath.row)
//                        tableView.deleteRows(at: [indexPath], with: .left)
                    }
                }
            
            
            
            tableView.endUpdates()
        }
    }
    
}

