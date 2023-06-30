//
//  LoginViewController.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 17/04/2023.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class LoginViewController: UIViewController {

    private let spinner = JGProgressHUD(style: .dark)
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private let imageView: UIImageView = {
    let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
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
        field.placeholder = "Mật khẩu..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .secondarySystemBackground 
        field.isSecureTextEntry = true
        return field
    }()
    private let loginButton: UIButton = {
    let button = UIButton()
        button.setTitle("Đăng nhập", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Đăng nhập"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Đăng ký",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegister))
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)
        emailField.delegate = self
        passwordField.delegate = self
        view.addSubview(scrollView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(imageView)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width - size) / 2, y: 20,
                                 width: size, height: size)
        
        emailField.frame = CGRect(x: 30, y: imageView.bottom + 10,
                                  width: scrollView.width - 60, height: 52)
        
        passwordField.frame = CGRect(x: 30, y: emailField.bottom + 10,
                                  width: scrollView.width - 60, height: 52)
        
        loginButton.frame = CGRect(x: 30, y: passwordField.bottom + 10,
                                  width: scrollView.width - 60, height: 52)
    }
    @objc private func loginButtonTapped() {
        guard let email = emailField.text, let password = passwordField.text, !email.isEmpty, !password.isEmpty, password.count >= 6 else {
            alertUserLoginError()
            return
        }
        spinner.show(in: view)
        
        // Firebase Login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: { [weak self] authResule, error in
            guard let strongSelf = self else {
            return
                
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard let result = authResule, error == nil else {
                print("Đăng nhập không thành công Lỗi: \(error)")
                return
            }
            let user = result.user
            
            let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                        let firstName = userData["first_name"] as? String,
                        let lastName = userData["last_name"] as? String else {
                            return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                case .failure(let error):
                    print("Lỗi khi đọc data: \(error)")
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            
            print("Đăng nhập thành công \(user)")
            strongSelf.navigationController?.dismiss(animated: true, completion: nil)
            
//            DatabaseManager.shared.userExists(with: email, completion: { exists in
//                if !exists {
//                    let chatUser = ChatAppUser(firstName: , lastName: <#T##String#>, emailAddress: email)
//                    DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
//                        if success {
//                            let filename = chatUser.profilePictureFileName
//                            Storagemaneger.shared.uploadProfileAvatar(with: data, fileName: filename, completion: { result in
//                                switch result {
//                                case .success(let downloadUrl):
//                                    UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
//                                    print(downloadUrl)
//                                case .failure(let error):
//                                    print("Lưu trữ lỗi: \(error)")
//                                }
//                            })
//                        }
//                    })
//                }
//            })
        })
    }
    func alertUserLoginError() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        let alert = UIAlertController(title: "Thông báo", message: "Vui lòng nhập thông tin hợp lệ", preferredStyle: .alert)
        alert.addAction((UIAlertAction(title: "Bỏ qua", style: .cancel, handler: nil)))
        present(alert, animated: true)
    }
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Create Account"
        navigationController?.pushViewController(vc, animated: true)
    }
}
extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}
