//
//  ProfileViewController.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 17/04/2023.
//

import UIKit
import FirebaseAuth
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
    
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Tên: \(UserDefaults.standard.value(forKey: "name") as? String ?? "Trống")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .info,
                                     title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "Trống")",
                                     handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout,
                                     title: "Đăng xuất",
                                     handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let actionSheet = UIAlertController(title: "",
                                                message: "",
                                                preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Đăng xuất",
                                                style: .destructive,
                                                handler: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                UserDefaults.standard.setValue(nil, forKey: "email")
                UserDefaults.standard.setValue(nil, forKey: "name")
                
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    strongSelf.present(nav, animated: true)
                } catch {
                    print("Đăng xuất không thành công")
                }
            }))
            actionSheet.addAction((UIAlertAction(title: "Bỏ qua",
                                                 style: .cancel,
                                                 handler: nil)))
            strongSelf.present(actionSheet, animated: true)
        }))
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = createTableHeader()
    }
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "image/" + fileName
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2, y: 75, width: 150, height: 150))
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.cornerRadius = imageView.width/2
        headerView.layer.masksToBounds = true
        headerView.addSubview(imageView)
        StorageManeger.shared.downloadUrl(for: path, completion: { resule in
            switch resule {
            case .success(let url):
                imageView.sd_setImage(with: url, completed: nil)
            case .failure(let error):
                print("Lỗi tải ảnh xuống: \(error)")
            }
        })
        return headerView
    }
}
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = data[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        cell.setUp(with: viewModel)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
        
    }
}
class ProfileTableViewCell: UITableViewCell {
    
    static let identifier = "ProfileTableViewCell"
    
    public func setUp(with viewModel: ProfileViewModel) {
        self.textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textColor = .black
            textLabel?.textAlignment = .left
            selectionStyle = .none
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .left
        }
    }
}
