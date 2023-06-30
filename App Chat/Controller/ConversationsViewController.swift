//
//  ViewController.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 17/04/2023.
//

import UIKit
import FirebaseAuth
import JGProgressHUD
import Foundation

struct Conversation {
    let id: String
    let name: String
    let ortherUserEmail: String
    let latestMessage: LatestMessage
}
struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
class ConversationsViewController: UIViewController {

    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
        return table
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "Trò chuyện trống"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight:  . medium)
        return label
    }()
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        startListeningForConversations()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.startListeningForConversations()
        })
    }
    private func startListeningForConversations() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        print("Bắt đầu tìm các đoạn hội thoại")
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
            switch result {
                case .success(let conversations):
                    print("Tải thành công các đoạn hội thoại")
                    guard !conversations.isEmpty else {
                        self?.tableView.isHidden = true
                        self?.noConversationsLabel.isHidden = false
                        return
                }
                self?.tableView.isHidden = false
                self?.conversations = conversations
                self?.noConversationsLabel.isHidden = true
                    
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
                case . failure(let error):
                    print("Lỗi tải hội thoại: \(error)")
            }
        })
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewConversationViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentConversations = strongSelf.conversations
            if let targetConversation = currentConversations.first(where: {
                $0.ortherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)
            }) {
                let vc = ChatViewController(with: targetConversation.ortherUserEmail, id: targetConversation.id)
                vc.isNewConversation = false
                vc.title = targetConversation.name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
            
            strongSelf.createNewConversation(result: result)
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
    }
    private func createNewConversation(result: SearchResult) {
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email)
        // Kiểm tra database nếu cuộc trò chuyện với hai người dùng này tồn tại
        // Nếu đúng, hãy sử dụng lại ID hội thoại
        // Nếu không thì sử dụng mã hiện có
        DatabaseManager.shared.conversationExists(with: email, completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
            }
        })
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(x: 10, y: (view.height - 100) / 2,
                                            width: view.width - 20, height: 100)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    private func validateAuth() {
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
}
extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = conversations[indexPath.row]
        openConversation(model)
//        tableView.deselectRow(at: indexPath, animated: true)
//        let vc = ChatViewController(with: model.ortherUserEmail, id: model.id)
//        vc.title = model.name
//        vc.navigationItem.largeTitleDisplayMode = .never
//        navigationController?.pushViewController(vc, animated: true)
    }
    func openConversation(_ model: Conversation) {
        let vc = ChatViewController(with: model.ortherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            
            DatabaseManager.shared.deleteConversation(conversationId: conversationId, completion: { [weak self] success in
                if success {
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                    }
            })
            tableView.endUpdates()
        }
    }
}
