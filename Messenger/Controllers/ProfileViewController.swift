//
//  ProfileViewController.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}

class ProfileViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    private var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(
            ProfileTableViewCell.self,
            forCellReuseIdentifier: ProfileTableViewCell.identifier
        )
        
        setData()
        //        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableView()
        
    }
    
    private func setData() {
        data.append(
            ProfileViewModel(
                viewModelType: .info,
                title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                handler: nil
            )
        )
        data.append(
            ProfileViewModel(
                viewModelType: .info,
                title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                handler: nil
            )
        )
        data.append(
            ProfileViewModel(
                viewModelType: .logout,
                title: "Log Out",
                handler: { [weak self] in
                    // Part 18 51:30
                    self?.setupUserData()
                    
                }
            )
        )
    }
    
    private func createTableView() -> UIView? {
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String
        else { return nil }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "image/" + fileName
        
        let headerView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: self.view.width,
                height: 300
            )
        )
        
        headerView.backgroundColor = .link
        
        let imageView = UIImageView(
            frame: CGRect(
                x: (view.width - 150) / 2,
                y: 75,
                width: 150,
                height: 150
            )
        )
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderWidth = 5
        imageView.layer.borderColor = UIColor.red.cgColor
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        
        StorageManager.shared.downloadURL(for: path) { result in
            
            //            guard let strongSelf = self else { return }
            
            switch result {
            case .success(let url):
                guard let url = URL(string: url) else { return }
                imageView.sd_setImage(with: url)
                
                //                strongSelf.downloadImage(imageView: imageView, url: url)
                
            case .failure(let error):
                
                print("failed to get download url: \(error)")
                
            }
        }
        return headerView
    }
    
    private func setupUserData() {
        
        let actionSheet = UIAlertController(
            title: "",
            message: "",
            preferredStyle: .actionSheet
        )
        
        actionSheet.addAction(UIAlertAction(
            title: "Log Out",
            style: .destructive
        ) {
            [weak self] _ in
            
            guard let strongSelf = self else {
                return
            }
            
            //LOG OUT FB
            FBSDKLoginKit.LoginManager().logOut()
            
            // log out Google
            GIDSignIn.sharedInstance.signOut()
            
            do {
                try FirebaseAuth.Auth.auth().signOut()
                
                let vc = LogInViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                strongSelf.present(nav, animated: true)
                
            } catch {
                print("Faied to log out")
            }
        })
        
        actionSheet.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )
        
        present(actionSheet, animated: true)
    }
    
    
    //    func downloadImage(imageView: UIImageView, url: URL) {
    //
    //        imageView.sd_setImage(with: url)
    //
    ////        URLSession.shared.dataTask(with: url) { data, _, error in
    ////
    ////            guard let data = data, error == nil else { return }
    ////
    ////            DispatchQueue.main.async {
    ////                let image = UIImage(data: data)
    ////                imageView.image = image
    ////
    ////            }
    ////        }.resume()
    //    }
    
    
    
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        data.count
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        
        let viewModel = data[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ProfileTableViewCell.identifier,
            for: indexPath
        ) as! ProfileTableViewCell
        
        cell.setUp(with: viewModel)
        
        //        var content = cell.defaultContentConfiguration()
        //
        //        content.text = data[indexPath.row]
        //        content.textProperties.alignment = .center
        //        content.textProperties.color = .red
        //
        //        cell.contentConfiguration = content
        
        return cell
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        data[indexPath.row].handler?()
        
        //        let actionSheet = UIAlertController(
        //            title: "",
        //            message: "",
        //            preferredStyle: .actionSheet
        //        )
        //
        //        actionSheet.addAction(UIAlertAction(
        //            title: "Log Out",
        //            style: .destructive
        //        ) {
        //            [weak self] _ in
        //
        //            guard let strongSelf = self else {
        //                return
        //            }
        //
        //            //LOG OUT FB
        //            FBSDKLoginKit.LoginManager().logOut()
        //
        //            // log out Google
        //            GIDSignIn.sharedInstance.signOut()
        //
        //            do {
        //                try FirebaseAuth.Auth.auth().signOut()
        //
        //                let vc = LogInViewController()
        //                let nav = UINavigationController(rootViewController: vc)
        //                nav.modalPresentationStyle = .fullScreen
        //                strongSelf.present(nav, animated: true)
        //
        //            } catch {
        //                print("Faied to log out")
        //            }
        //        })
        //
        //        actionSheet.addAction(
        //            UIAlertAction(
        //                title: "Cancel",
        //                style: .cancel
        //            )
        //        )
        //
        //        present(actionSheet, animated: true)
        
        
    }
    
    
}

class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"
    
    public func setUp(with viewModel: ProfileViewModel) {
        
        var content = defaultContentConfiguration()
        content.text = viewModel.title
        
        switch viewModel.viewModelType {
        case .info:
            content.textProperties.alignment = .natural
            self.selectionStyle = .none
        case .logout:
            content.textProperties.alignment = .center
            content.textProperties.color = .red
        }
        self.contentConfiguration = content
    }
    
}

