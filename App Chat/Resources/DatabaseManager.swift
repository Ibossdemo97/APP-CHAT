//
//  DatabaseManager.swift
//  App Chat
//
//  Created by Luyện Hà Luyện on 21/04/2023.
//

import Foundation
import FirebaseDatabase
import MessageKit
import AVFoundation
import AVKit
import MapKit
import CoreLocation

final class DatabaseManager {

    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
        
    }
}
extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}
extension DatabaseManager {
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEMail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            guard let strongSelf = self else {
                return
            }
            guard error == nil else {
                print("Lỗi tải dữ liệu lên database")
                completion(false)
                return
            }
            /*
             users =>   [
                            [
                                "name":
                                "safe_emai":
                            ],
                            [
                                "name":
                                "safe_emai":
                            ]
                        ]
             */
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //Thêm thông tin user dạng dictionary
                    let newElement = [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.safeEMail
                    ]
                    usersCollection.append(newElement)
                    
                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    //Tạo mảng
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEMail
                        ]
                    ]
                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    public func getAllUsers(completion : @escaping (Result<[[String:String]], Error >) -> Void) {
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String:String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    public enum DatabaseError: Error {
        case failedToFetch
    }
}
//Mark: - Gửi tin nhắn trên hội thoại
    /*
         "ạdhbhiq": {
            "messages": [
                {
                    "id": String
                    "type": text, photo, video
                    "content": String
                    "date": Date()
                    "sender_email": String
                    "is_read": true/false
                }
            ]
         }
     
         "conversation" =>   [
                        [
                            "conversation_Id": "ạdhbhiq"
                            "orther_user_email":
                             "laster_message":
                             "orther_user_email": => {
                                "date": Date(),
                                "laster_message": "message",
                                "is_read": true/false
                            }
                        ]
                    ]
     */
extension DatabaseManager {
    public func createNewConversation(with ortherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        //Tạo cuộc hội thoại mới với email và tin nhắn đầu tiên
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationId = "Conversation_\(firstMessage.messageId)"
            let newConversationData: [String:Any] = [
                "id": conversationId,
                "orther_user_email": ortherUserEmail,
                "name": name,
                 "laster_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            let recipient_newConversationData: [String:Any] = [
                "id": conversationId,
                "orther_user_email": safeEmail,
                "name": currentName,
                 "laster_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            //Cập nhật tin nhắn mới
            self?.database.child("\(ortherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //Append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(ortherUserEmail)/conversations").setValue(conversations)
                } else {
                    //create
                    self?.database.child("\(ortherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })
            //Cập nhật tin nhắn của người dùng hiện tại
            if var conversations = userNode["convaersations"] as? [[String: Any]] {
                //conversation array exists for current user
                //You should append
                conversations.append(newConversationData)
                userNode["conversation"] = conversations
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
            } else {
                //Mảng hội thoại không tồn tại
                //Tạo mới
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    private func finishCreatingConversation(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//            "id": String
//            "type": text, photo, video
//            "content": String
//            "date": Date()
//            "sender_email": String
//            "is_read": true/false
//        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        guard var myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name
        ]
        let value: [String: Any] = [
            "message": [
                collectionMessage
            ]
        ]
        print("Thêm mới hội thoại: \(conversationID)")
        
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        //Tìm và tải lên tất cả cuộc hội thoại của người dùng được gửi bằng email
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            var conversations: [Conversation] = value.compactMap({ dictionary in
                let conversationId = dictionary["id"] as? String ?? ""
                let name = dictionary["name"] as? String ?? ""
                let ortherUserEmail = dictionary["orther_user_email"] as? String ?? ""
                let latestMessage = dictionary["laster_message"] as? [String: Any] ?? ["": ""]
                let date = latestMessage["date"] as? String ?? ""
                let message = latestMessage["message"] as? String ?? ""
                let isRead = latestMessage["is_read"] as? Bool ?? false
                
//                guard let conversationId = dictionary["id"] as? String,
//                      let name = dictionary["name"] as? String,
//                      let ortherUserEmail = dictionary["orther_user_email"] as? String,
//                      let latestMessage = dictionary["latest_mesage"] as? [String: Any],
//                      let date = latestMessage["date"] as? String,
//                      let message = latestMessage["message"] as? String,
//                      let isRead = latestMessage["is_read"] as? Bool else {
//                        return nil
//                }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, ortherUserEmail: ortherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        //Tải về tát cả tin nhắn của cuộc hội thoại nhất định
        database.child("\(id)/message").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let messages: [Message] = value.compactMap({ dictionary in
                let name = dictionary["name"] as? String ?? ""
                let isRead = dictionary["is_read"] as? Bool ?? false
                let messageId = dictionary["id"] as? String ?? ""
                let content = dictionary["content"] as? String ?? ""
                let type = dictionary["type"] as? String ?? ""
                let senderEmail = dictionary["sender_email"] as? String ?? ""
                let dateString = dictionary["date"] as? String ?? ""
                let date = ChatViewController.dateFormatter.date(from: dateString)
//                guard let conversationId = dictionary["id"] as? String,
//                      let name = dictionary["name"] as? String,
//                      let ortherUserEmail = dictionary["orther_user_email"] as? String,
//                      let latestMessage = dictionary["latest_mesage"] as? [String: Any],
//                      let date = latestMessage["date"] as? String,
//                      let message = latestMessage["message"] as? String,
//                      let isRead = latestMessage["is_read"] as? Bool else {
//                        return nil
//                }
                var kind: MessageKind?
                if type == "photo" {
                    guard let imageUrl = URL(string: content),
                    let placeholder = UIImage(systemName: "plus") else {
                        return nil
                    }
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 260, height: 260))
                    kind = .photo(media)
                } else if type == "video" {
//                    self.makeThumbnail(from: content) { (thumbnail) in
//                        if let thumbnail = thumbnail {
//                            DispatchQueue.main.async {
//                                let imageThumbnail = UIImageView(image: thumbnail)
//                                guard let videoUrl = URL(string: content),
//                                      let placeholder = UIImage(systemName: "play.circle") else {
//                                    return nil
//                                }
//                                let media = Media(url: videoUrl,
//                                                  image: nil,
//                                                  placeholderImage: imageThumbnail,
//                                                  size: CGSize(width: 260, height: 260))
//                                kind = .video(media)
//                            }
//                        } else {
//                            kind = nil
//                        }
//                    }
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "play.circle") else {
                            return nil
                    }
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 260, height: 260))
                    kind = .video(media)
                } else if  type == "location" {
                    let locationComponents = content.components(separatedBy: ", ")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                        return nil
                    }
                    let location = Location(location: CLLocation(latitude: latitude,
                                                                 longitude: longitude),
                                            size: CGSize(width: 260, height: 260))
                    kind = .location(location)
                } else {
                    kind = .text(content)
                }
                guard let finalKind = kind else {
                    return nil
                }
                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date!,
                               kind: finalKind)
            })
            completion(.success(messages))
        })
    }
    //Gửi tin nhắn với cuộc trò chuyện và tin nhắn đk gửi
    public func sendMessage(to conversation: String, ortherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        // thêm tin nhắn mới vào đoạn hội thoại
        // cập nhật tin nhắn mới nhất của người gửi
        // cập nhật tin nhắn mới nhất của người nhận
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        database.child("\(conversation)/message").observeSingleEvent(of: .value, with:  { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
            completion(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                        message = targetUrlString
                }
                break
            case .video(let mediaItem):
                if let targetUrlString = mediaItem.url?.absoluteString {
                    message = targetUrlString
                }
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude), \(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            currentMessages.append(newMessageEntry)
            strongSelf
                .database.child("\(conversation)/message").setValue(currentMessages) { error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                        var databaseEntryConversations = [[String: Any]]()
                        let updateValue: [String:Any] = [
                            "date": dateString,
                            "is_read": false,
                            "message": message
                        ]
                        if var currentUserConversations = snapshot.value as?  [[String: Any]] {
                            //Tạo đường dẫn tới cuộc trò chuyện
                            var targetConversation: [String: Any]?
                            var position = 0
                            for conversationDictionary in currentUserConversations {
                                if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                            if var targetConversation = targetConversation {
                                targetConversation["laster_message"] = updateValue
                                currentUserConversations[position] = targetConversation
                                databaseEntryConversations = currentUserConversations
                            } else {
                                let newConversationData: [String:Any] = [
                                    "id": conversation,
                                    "orther_user_email": DatabaseManager.safeEmail(emailAddress: ortherUserEmail),
                                    "name": name,
                                     "laster_message": updateValue
                                ]
                                currentUserConversations.append(newConversationData)
                                databaseEntryConversations = currentUserConversations
                            }
                        } else {
                            let newConversationData: [String:Any] = [
                                "id": conversation,
                                "orther_user_email": DatabaseManager.safeEmail(emailAddress: ortherUserEmail),
                                "name": name,
                                 "laster_message": updateValue
                            ]
                            databaseEntryConversations = [newConversationData]
                        }

                        strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                            guard error == nil else {
                                completion(false)
                                return
                            }
                            //Cập nhật tin nhắn mới nhất cho người nhận
                            strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                                    let updateValue: [String:Any] = [
                                        "date": dateString,
                                        "is_read": false,
                                        "message": message
                                    ]
                                var databaseEntryConversations = [[String: Any]]()
                                
                                guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
                                    return
                                }
                                
                                if var ortherUserConversations = snapshot.value as?  [[String: Any]] {
                                    var targetConversation: [String: Any]?
                                    var position = 0
                                    for conversationDictionary in ortherUserConversations {
                                        if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                            targetConversation = conversationDictionary
                                            break
                                        }
                                        position += 1
                                    }
                                    if var targetConversation = targetConversation {
                                        targetConversation["laster_message"] = updateValue
                                        ortherUserConversations[position] = targetConversation
                                        databaseEntryConversations = ortherUserConversations
                                    } else {
                                        //không tìm thấy trong collection hiện tại
                                        let newConversationData: [String:Any] = [
                                            "id": conversation,
                                            "orther_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                            "name": currentEmail,
                                             "laster_message": updateValue
                                        ]
                                        ortherUserConversations.append(newConversationData)
                                        databaseEntryConversations = ortherUserConversations
                                    }
                                } else {
                                    //Collection hiện tại không tồn tại
                                    let newConversationData: [String:Any] = [
                                        "id": conversation,
                                        "orther_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name": currentEmail,
                                         "laster_message": updateValue
                                    ]
                                    databaseEntryConversations = [newConversationData]
                                }
                                strongSelf.database.child("\(ortherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                                    guard error == nil else {
                                        completion(false)
                                        return
                                    }
                                    completion(true)
                                })
                            })
                        })
                    })
                }
        })
    }
//    func makeThumbnail(from videoURL: URL, completion: @escaping (UIImage?) -> Void) {
//        let asset = AVAsset(url: videoURL)
//        let imageGenerator = AVAssetImageGenerator(asset: asset)
//        imageGenerator.appliesPreferredTrackTransform = true
//        //Dùng hình ảnh đầu tiên của video như thumbnail
//        let time = CMTime(seconds: 0, preferredTimescale: 1)
//        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { (_, image, _, _, _) in
//            if let cgImage = image {
//                let thumbnail = UIImage(cgImage: cgImage)
//                completion(thumbnail)
//            } else {
//                completion(nil)
//            }
//        }
//    }
//    func fetchVideoThumbnail(from videoURL: URL) {
//        DispatchQueue.global().async {
//            if let data = try? Data(contentsOf: videoURL),
//                let thumbnail = UIImage(data: data) {
//                    print("💙💙\(thumbnail)")
//            } else {
//            }
//        }
//    }
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        //Lấy dữ liệu tất cả các cuộc hội thoại cho user hiện tại
        //Xoá đoạn hội thoại có conversationID trên
        //reset những đoạn hội thoại của user
        print("Đang xoá cuộc hội thoại: \(conversationId)")
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: { snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String,
                       id == conversationId {
                        print("Tìm thấy đoạn hội thoại cần xoá")
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: { error, _ in
                    guard error == nil else {
                        print("không thể viết mảng hội thoại mới")
                        completion(false)
                            return
                    }
                    print("Xoá thành công đoạn hội thoại")
                    completion(true)
                })
            }
        })
    }
    public func conversationExists( with targetRecipientEmail: String, completion: @escaping (Result<String, Error>) -> Void) {
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            //Lặp lại và tìm cuộc trò chuyện với người gửi mục tiêu
            if let conversation = collection.first(where:  {
                guard let targetSenderEmail = $0["orther_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }) {
                // Get id
                guard let id = conversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}
struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEMail: String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName: String {
        return "\(safeEMail)_profile_picture.png"
    }
}
