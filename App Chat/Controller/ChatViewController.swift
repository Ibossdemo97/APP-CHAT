//
//  ChatViewController.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 25/04/2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import MobileCoreServices
import AVFoundation
import AVKit
import CoreLocation
import MapKit

var videoUrl: URL?

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
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}
struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
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

    private var senderPhotoURL: URL?
    private var ortherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public var isNewConversation = false
    public let ortherUserEmail: String
    public var conversationId: String?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(photoURL: "",
               senderId: safeEmail,
               displayName: "Tôi")
    }
    init(with email: String, id: String?) {
        self.conversationId = id
        self.ortherUserEmail = email
        super.init(nibName: nil, bundle: nil)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) chưa được triển khai")
    }
    
//    let messageCellDelegate = ChatViewCollectionCellDelegate()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
//        messagesCollectionView.messageCellDelegate = messageCellDelegate
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Thêm file", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Hình Ảnh", style: .default, handler: { [weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: { [weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Âm thanh", style: .default, handler: { _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Vị trí", style: .default, handler: { [weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel, handler: nil ))
        present(actionSheet, animated: true)
    }
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Chọn ảnh", message:  nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Máy ảnh", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Thư viện", style: .default, handler: { [weak self]  _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel, handler: { _ in
            
        }))
        present(actionSheet, animated: true)
    }
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Chọn video", message:  nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Máy ảnh", style: .default, handler: { [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Thư viện", style: .default, handler: { [weak self]  _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            self?.present(picker, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel, handler: { _ in
            
        }))
        present(actionSheet, animated: true)
    }
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Chọn vị trí"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoorindates in
            guard let strongSelf = self else {
                return
            }
            guard
                let messageId = self?.createMessageId(),
                let conversationId = self?.conversationId,
                let name = self?.title,
                let selfSender = self?.selfSender else {
                return
            }
            
            let longitude = selectedCoorindates.longitude
            let latitude = selectedCoorindates.latitude
            print("long = \(longitude) | lat = \(latitude)")
            
            let location = Location(location: CLLocation(latitude: latitude,
                                                      longitude: longitude),
                                 size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            DatabaseManager.shared.sendMessage(to: conversationId, ortherUserEmail: strongSelf.ortherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("Gửi tin nhắn vị trí thành công")
                } else {
                    print("Lỗi gửi tin nhắn vị trí")
                }
            })
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                print("Nhận tin nhắn thành công: \(messages)")
                guard !messages.isEmpty else {
                    print("Trống")
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }

            case .failure(let error):
                print("Lỗi tải tin nhắn: \(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
}
extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true,completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard
            let messageId = createMessageId(),
            let conversationId = conversationId,
            let name = self.title,
            let selfSender = selfSender else {
            return
        }
        if let image = info[.editedImage] as? UIImage,
           let imageData = image.pngData() {
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            //Tải lên ảnh
            StorageManeger.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    //Sẵn sàng gửi tin nhắn ảnh
                    print("Đang tải ảnh lên: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url, image: nil, placeholderImage:  placeholder, size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, ortherUserEmail: strongSelf.ortherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print("Gửi tin nhắn ảnh")
                        } else {
                            print("Lỗi gửi tin nhắn ảnh")
                        }
                    })
                case .failure(let error):
                    print("Lỗi tải ảnh lên: \(error)")
                }
            })
        } else if let videoUrl = info[.mediaURL] as? URL {
//            let fileManager = FileManager.default
//            if fileManager.fileExists(atPath: videoUrl.path) {
//                print("💙💙💙💙videoUrl có tồn tại")
//            } else {
//                print("videoUrl có không tồn tại")
//            }
            let fileName = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
//            Tải lên video
//            let data = try! Data(contentsOf: videoUrl)
//            StorageManeger.storage.child("message_video/\(fileName)").putData(data, completion: {
//            metadata, error in
//                if let error = error as NSError? {
//                    let errorMessage = error.localizedDescription
////                    print("🥶🥶🥶Lỗi tải lên video - Mã lỗi: \(errorCode!.rawValue) - \(errorMessage)")
//                } else {
//                    print("🥶🥶🥶🥶Lỗi tải lên video: Lỗi không xác định")
//                }
//            })
            let data = try! Data(contentsOf: videoUrl)
            print("🥶🥶🥶🥶\(videoUrl)")
            StorageManeger.shared.uploadMessageVideo(with: data, fileName: fileName, completion:  { [weak self] result in
//            StorageManeger.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in 
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    //Sẵn sàng gửi tin nhắn video
                    print("Đang tải video lên: \(urlString)")

                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }

                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage:  placeholder,
                                      size: .zero)

                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, ortherUserEmail: strongSelf.ortherUserEmail, name: name, newMessage: message, completion: { success in
                        if success {
                            print("Gửi tin nhắn video")
                        } else {
                            print("Lỗi gửi tin nhắn video")
                        }
                    })
                case .failure(let error):
                    print("Lỗi tải video lên: \(error)")
                }
            })
        }
    }
}
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageId = createMessageId() else {
                    return
        }
        print("Đang gửi: \(text)")
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        //Gửi tin nhắn
        if isNewConversation {
            //Tạo đoạn hội thoại trên database
            DatabaseManager.shared.createNewConversation(with: ortherUserEmail, name: self.title ?? "User", firstMessage: message, completion: { [weak self] succues in
                if succues {
                    print("Tin nhắn đã gửi")
                    self?.isNewConversation = false
                    let newConversationId = "Conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                } else {
                    print("Lỗi gửi tin nhắn")
                }
            })
        } else {
            //Thêm dòng tin nhắn vào hội thoại hiện có
            guard let conversationId = conversationId, let name = self.title else {
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, ortherUserEmail: ortherUserEmail, name: name, newMessage: message, completion: { success in
                if success {
                    print("Tin nhắn đã gửi")
                } else {
                    print("Không thể gửi tin nhắn")
                }
            })
        }
        inputBar.inputTextView.text = ""
    }
    private func createMessageId() -> String? {
        //Date, ortherUserEmail, senderEmail, randomInt
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(ortherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("Tạo id tin nhắn: \(newIdentifier)")
        return newIdentifier
    }
}
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil, email shout be cached")
    }
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        case .video(let media):
            guard let videoURL = media.url else {
                return
            }
            let asset = AVAsset(url: videoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                // Get the first frame of the video as a thumbnail
                let time = CMTime(seconds: 0, preferredTimescale: 1)
                
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { (_, image, _, _, _) in
                    if let cgImage = image {
                        let thumbnail = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async {
                            imageView.image = thumbnail
                                }
                    } else {
                        
                    }
                }
        default:
            break
        }
    }
//    func generateThumbnail(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> UIImage? {
//        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
//        let mapSnapshotOptions = MKMapSnapshotter.Options()
//
//        // Đặt khu vực sẽ được chụp dựa trên vĩ độ và kinh độ được cung cấp
//        let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
//        mapSnapshotOptions.region = region
//        mapSnapshotOptions.scale = UIScreen.main.scale
//        mapSnapshotOptions.size = CGSize(width: 260, height: 260) // Set the desired thumbnail size
//
//        let mapSnapshotter = MKMapSnapshotter(options: mapSnapshotOptions)
//
//        var thumbnailImage: UIImage?
//
//        let semaphore = DispatchSemaphore(value: 0)
//
//        mapSnapshotter.start { snapshot, error in
//            if let snapshot = snapshot {
//                thumbnailImage = snapshot.image
//            }
//            semaphore.signal()
//        }
//
//        _ = semaphore.wait(timeout: .distantFuture)
//
//        return thumbnailImage
//    }
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId != selfSender?.senderId {
            //our message that we've sent
            return .white
        }
        return .link
    }
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        switch message.kind {
        case .text(_):
            return .black
        default:
            break
        }
        return .black
    }
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            if let currentUserImage = self.senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImage, completed: nil)
            } else {
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "image/\(safeEmail)_profile_picture.png"
                StorageManeger.shared.downloadUrl(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case . failure(let error):
                        print("Lỗi ở ChatViewController: \(error)")
                    }
                })
            }
        } else {
            if let ortherUserImage = self.ortherUserPhotoURL {
                avatarView.sd_setImage(with: ortherUserImage, completed: nil)
            } else {
                let email = self.ortherUserEmail
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "image/\(safeEmail)_profile_picture.png"
                StorageManeger.shared.downloadUrl(for: path, completion: { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.ortherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("Lỗi ở ChatViewController: \(error)")
                    }
                })
            }
        }
    }
}
extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.ispi
            vc.title = "Chia sẻ vị trí"
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoviewerViewController(with: imageUrl)
            self.navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            present(vc, animated: true)
        default:
            break
        }
    }
}



