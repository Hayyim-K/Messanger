//
//  LogInViewController.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit
import FirebaseAuth
import FacebookLogin
import FirebaseCore
import GoogleSignIn
import JGProgressHUD

class LogInViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email"
        
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 11, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        
        return field
    }()
    
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password"
        field.isSecureTextEntry = true
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 11, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground
        
        return field
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "faceid")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private let faceBookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        return button
    }()
    
    private let googleLogInButton = GIDSignInButton()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(
            forName: .didLogInNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                guard let strongSelf = self else { return }
                
                strongSelf.navigationController?.dismiss(animated: true)
            }
        )
        
        //        GIDSignIn.sharedInstance.signIn(withPresenting: self)
        
        //        googleLogIn()
        
        emailField.delegate = self
        passwordField.delegate = self
        
        title = "Log In"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegister))
        
        loginButton.addTarget(
            self,
            action: #selector(loginButtonTapped),
            for: .touchUpInside
        )
        
        
        faceBookLoginButton.delegate = self
        
        googleLogInButton.addTarget(
            self,
            action: #selector(googleLogIn),
            for: .touchUpInside
        )
        
        //AddSubviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(faceBookLoginButton)
        scrollView.addSubview(googleLogInButton)
        
        if let token = AccessToken.current, !token.isExpired {
            
        }
    }
    
    deinit {
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width - size) / 2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        emailField.frame = CGRect(x: 30,
                                  y: imageView.bottom + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.bottom + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.bottom + 10,
                                   width: scrollView.width - 60,
                                   height: 52)
        
        faceBookLoginButton.frame = CGRect(x: 30,
                                           y: loginButton.bottom + 10,
                                           width: scrollView.width - 60,
                                           height: 52)
        
        googleLogInButton.frame = CGRect(x: 30,
                                         y: faceBookLoginButton.bottom + 10,
                                         width: scrollView.width - 60,
                                         height: 52)
        
        //        faceBookLoginButton.frame.origin.y = loginButton.bottom + 20
        
    }
    
    private func safeReturnToBeginning() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let delegate = windowScene.delegate as? SceneDelegate {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let initialViewController = storyboard.instantiateInitialViewController()
            delegate.window?.rootViewController = initialViewController
        }
    }
    
    // - MARK: EMAIL LOG IN
    @objc private func loginButtonTapped() {
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text?.lowercased(),
              let password = passwordField.text,
              !email.isEmpty,
              password.count >= 6 else {
            allertUserLoginError()
            return
        }
        
        spinner.show(in: view)
        
        
        FirebaseAuth.Auth.auth().signIn(
            withEmail: email,
            password: password
        ) { [weak self] authDataResult, error in
            
            guard let strongSelf = self else { return }
            
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            
            guard let result = authDataResult, error == nil
            else {
                print("Faild to log in user with email: \(email)")
                return
            }
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            
            DatabaseManager.shared.getDataFor(path: safeEmail) { result in
                switch result {
                case .success(let data):
                    
                    guard let userData = data as? [String : Any],
                          let firstName = userData["firstName"] as? String,
                          let lastName = userData["lastName"] as? String
                    else { return }

//                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                    UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):

                    print("Failed to read data with error \(error)")
                }
            }
            
            UserDefaults.standard.setValue(email, forKey: "email")
            
            
            //            guard let displayName = user.displayName else { return }
            //            UserDefaults.standard.set("\(displayName)", forKey: "name")
            
            
            print("Logged In User: \(user)")
            
            strongSelf.navigationController?.dismiss(animated: true){
                strongSelf.safeReturnToBeginning()
            }
        }
        
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
    
    //FireBaseLogIn
    
    func allertUserLoginError() {
        let alert = UIAlertController(title: "Woops",
                                      message: "Please enter all information to log in",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        
        present(alert, animated: true)
    }
    
}

extension LogInViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
    
    
}

// - MARK: FACEBOOK
extension LogInViewController: LoginButtonDelegate {
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
        
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        
        if let error = error {
            print("Error - \(error.localizedDescription)")
            return
        } else {
            //    }
            //
            //    func loginButton(_ loginButton: FBSDKLoginKit.FBLoginButton, didCompleteWith result: FBSDKLoginKit.LoginManagerLoginResult?, error: Error?) {
            //
            guard let token = AccessToken.current?.tokenString else {
                print("User failed to log in with Facebook")
                return
            }
            
            
            
            let faceBookRequest = FBSDKLoginKit.GraphRequest(
                graphPath: "me",
                parameters: ["fields" : "email, name, first_name, last_name, picture.type(large)"],
                tokenString: token,
                version: nil,
                httpMethod: .get
            )
            
            faceBookRequest.start {
                _,
                result,
                error in
                guard let result = result as? [String : Any],
                      error == nil else {
                    print("Faild to make facebook graph request - \(error!)")
                    return
                }
                
//                print("\nWWWWWWWWWWWWWWW!WWWWWWWWŴ\n\(result)")
                
                guard let firstName = result["first_name"] as? String,
                      let lastName = result["last_name"] as? String,
                      let email = result["email"] as? String,
                let picture = result["picture"] as? [String : Any],
                let data = picture["data"] as? [String : Any],
                let pictureUrl = data["url"] as? String else {
                    print("Faield to get email and name from fb result")
                    return
                }
                
                UserDefaults.standard.set(email, forKey: "email")
                UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                
                //                let nameComponents = userName.components(separatedBy: " ")
                //                guard nameComponents.count == 2 else { return }
                //
                //                let firstName = nameComponents[0]
                //                let lastName = nameComponents[1]
                
                DatabaseManager.shared.userExists(with: email) { exists in
                    if !exists {
                        //insert to database
                        let chatUser = ChatAppUser(
                            firstName: firstName,
                            lastName: lastName,
                            emailAddress: email
                        )
                        DatabaseManager.shared.insertUser(with: chatUser) { success in
                            if success {
                                
                                guard let url = URL(string: pictureUrl) else { return }
                                
                                print("Download data from facebook image")
                                
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    
                                    guard let data = data else  {
                                        print("Failed to get data from FB")
                                        return
                                    }
                                    
                                    print("got data from FB uploding...")
                                    
                                    //upload image
                                    //                                    guard let image = self.imageView.image,
                                    //                                          let data = image.pngData() else { return }
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(
                                        with: data,
                                        fileName: fileName) { result in
                                            switch result {
                                            case .success(let downloadUrl):
                                                UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                                print(downloadUrl)
                                            case .failure(let error):
                                                print("Storage manager error: \(error)")
                                            }
                                        }
                                }.resume()
                                
                                
                            }
                        }
                    }
                }
                
                let credential = FacebookAuthProvider.credential(withAccessToken: token)
                
                FirebaseAuth.Auth.auth().signIn(with: credential){ [weak self] authResult, error in
                    guard let strongSelf = self else { return }
                    
                    guard let _ = authResult, error == nil else {
                        if let error = error {
                            print("Facebook credential login failed, MFA may be needed - \(error)")
                        }
                        return
                    }
                    
                    print("Successfully logged user in faceBook")
                    strongSelf.navigationController?.dismiss(animated: true) {
                        strongSelf.safeReturnToBeginning()
                    }
                    
                }
            }
        }
    }
    
}

// - MARK: GOOGLE
extension LogInViewController {
    
    
    @objc private func googleLogIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        //Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        //Start the sign in flow
        GIDSignIn.sharedInstance.signIn(withPresenting: self) {
            [unowned self] result,
            error in
            guard error == nil else {
                print("Faild to sign in with Google: \(error!)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                print("Faild to sign in with Google becouse of token problem")
                return
            }
            
            print("Did sign in with Google: \(user)")
            
            guard let email = user.profile?.email,
                  let firstName = user.profile?.givenName,
                  let lastName = user.profile?.familyName else { return }
            
            UserDefaults.standard.setValue(email, forKey: "email")
            UserDefaults.standard.setValue("\(firstName) \(lastName)", forKey: "name")
            
            
            DatabaseManager.shared.userExists(with: email) { exists in
                if !exists {
                    //insert to database
                    let chatUser = ChatAppUser(
                        firstName: firstName,
                        lastName: lastName,
                        emailAddress: email
                    )
                    DatabaseManager.shared.insertUser(with: chatUser) { success in
                        if success {
                            //upload image
                            guard let isImage = user.profile?.hasImage else { return }
                            
                            if isImage {
                                guard let url = user.profile?.imageURL(withDimension: 200)
                                else { return }
                                
                                URLSession.shared.dataTask(with: url) { data, _, _ in
                                    guard let data = data else { return }
                                    
                                    // guard let image = self.imageView.image,
                                    // let data = image.pngData() else { return }
                                    
                                    let fileName = chatUser.profilePictureFileName
                                    StorageManager.shared.uploadProfilePicture(
                                        with: data,
                                        fileName: fileName) { result in
                                            switch result {
                                            case .success(let downloadUrl):
                                                UserDefaults.standard.setValue(downloadUrl, forKey: "profile_picture_url")
                                                print(downloadUrl)
                                            case .failure(let error):
                                                print("Storage manager error: \(error)")
                                            }
                                        }
                                }.resume()
                            }
                        }
                    }
                }
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential){ [weak self] authResult, error in
                
                guard let _ = authResult, error == nil else {
                    if let error = error {
                        print("Google credential login failed, MFA may be needed - \(error)")
                    }
                    return
                }
                
                print("Successfully logged user in Google")
                
                NotificationCenter.default.post(name: .didLogInNotification, object: nil)
                
                self?.navigationController?.dismiss(animated: true) {
                    self?.safeReturnToBeginning()
                }
                
            }
            
            
        }
    }
}
