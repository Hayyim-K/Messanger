//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit
import JGProgressHUD

struct SearchResult {
    let name: String
    let email: String
}


class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) -> Void)?
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String : String]]()
    
    private var results = [SearchResult]()
    
    private var hasFetched = false
    
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for Users..."
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.isHidden = true
        tableView.register(
            NewConversationCell.self,
            forCellReuseIdentifier: NewConversationCell.identifier
        )
        
        return tableView
    }()
    
    private let noResultsLabel: UILabel = {
       let label = UILabel()
        label.isHidden = true
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .green
        label.font = .systemFont(ofSize: 21, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(noResultsLabel)
        view.addSubview(tableView)
        
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        
        view.backgroundColor = .white
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .done,
            target: self,
            action: #selector(dismissSelf)
        )
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(
            x: view.width / 4,
            y: (view.height - 200) / 2,
            width: view.width / 2,
            height: 200
        )
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    
    
}

extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        results.count
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        
        let model = results[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NewConversationCell.identifier,
            for: indexPath
        ) as! NewConversationCell
        
        cell.configure(with: model)
        
//        var content = cell.defaultContentConfiguration()
//        content.text = results[indexPath.row].name
//        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        //start conversation
        let targetUserData = results[indexPath.row]
        
        dismiss(animated: true) { [weak self] in
            self?.completion?(targetUserData)
        }
    }
   
    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        90
    }
    
}

extension NewConversationViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(
                of: " ",
                with: ""
              ).isEmpty else {
            return
        }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        
        spinner.show(in: view)
        
        self.searchUsers(query: text)
    }
    
    func searchUsers(query: String) {
        //check if array has fireBase results
        if hasFetched {
            // if it does: filter
            filterUsers(with: query)
            
        } else {
            // if not, fetch then filter
            DatabaseManager.shared.getAllUsers { [ weak self ] result in
                switch result {
                case .success(let usersCollection):
                    self?.hasFetched = true
                    self?.users = usersCollection
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print("Failed to get users: \(error)")
                }
            }
        }
        
        
    }
    
    func filterUsers(with term: String) {
        // update the UI: either show results or show on results label
        guard hasFetched,
              let currentUserEmail = UserDefaults
            .standard
            .value(forKey: "email") as? String
        else { return }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        self.spinner.dismiss()
        
        let results: [SearchResult] = self.users.filter {
            
            guard let name = $0["name"]?.lowercased(),
                  let email = $0["email"],
                  email != safeEmail
            else { return false }
            
            return name.hasPrefix(term.lowercased())
            
        }.compactMap {
            
            guard let email = $0["email"],
                  let name = $0["name"]
            else { return nil }
            
            return SearchResult(name: name, email: email)
            
        }
        
        self.results = results
        
        updateUI()
        
    }
    
    func updateUI() {
        if results.isEmpty {
            self.noResultsLabel.isHidden = false
            self.tableView.isHidden = true
//            self.tableView.reloadData()
        } else {
            self.noResultsLabel.isHidden = true
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
    
}

//extension NewConversationViewController: UITableViewDelegate {
//
//}
