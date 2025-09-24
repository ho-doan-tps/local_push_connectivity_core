import Foundation
import Network
import UserNotifications

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictionaryValue = try? container.decode([String: AnyDecodable].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
}

struct Notification: Decodable {
    var Title: String
    var Body: String
}

struct Message: Decodable {
    var notification: Notification
    var data: [String: Any]
    
    private enum CodingKeys: String, CodingKey {
        case Data
        case Notification
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notification = try container.decode(Notification.self, forKey: .Notification)
        data = try container.decode([String: AnyDecodable].self, forKey: .Data).mapValues { $0.value }
    }
}

struct Sender: Codable {
    var connectorID: String
    var connectorTag: String
    var deviceID: String

    init(connectorID: String, connectorTag: String, deviceID: String) {
        self.connectorID = connectorID
        self.connectorTag = connectorTag
        self.deviceID = deviceID
    }
}

struct DataRegister: Codable {
    var apnsToken: String?
    var applicationID: String?
    var apnsServerType: Int?
    
    init(apnsToken: String? = nil, applicationID: String? = nil, apnsServerType: Int? = nil) {
        self.apnsToken = apnsToken
        self.applicationID = applicationID
        self.apnsServerType = apnsServerType
    }
}

struct RegisterModel: Codable {
    var messageType: String
    var systemType: Int
    var sender: Sender
    var data: DataRegister
    
    init(messageType: String, sender: Sender, data: DataRegister, systemType: Int) {
        self.messageType = messageType
        self.sender = sender
        self.data = data
        self.systemType = systemType
    }
}

struct PingModel: Codable {
    var messageType: String?
    
    init(messageType: String? = nil) {
        self.messageType = messageType
    }
}

struct PongModel: Codable {
    var pong: String?
    
    init(pong: String? = nil) {
        self.pong = pong
    }
}



@available(macOS 10.15, *)
public class ISocket {
    public enum State: String, Equatable {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }
    
    public func register() -> ISocket {
        let settings = Self.fetchSettings()
        if settings.useTcp ?? false {
            if settings.publicKey != nil && !settings.publicKey!.isEmpty {
                
            }
        }
        return WebSocketClient()
    }
    
    public var state: State = .disconnected
    let dispatchQueue = DispatchQueue(label: "NetworkSession.dispatchQueue",qos: .background)
    let dispatchPingQueue = DispatchQueue(label: "NetworkSession.dispatchPingQueue")
    let retryInterval = DispatchTimeInterval.seconds(5)
    var retryWorkItem: DispatchWorkItem?
    
    var pingTimer: DispatchSourceTimer? = nil
    
    private static let settingsKey = "settings"
    private static let appStateKey = "isExecutingInBackground"
    private static let groupId = Bundle.main.object(forInfoDictionaryKey: "GroupNEAppPushLocal") as? String
    private static let userDefaults: UserDefaults = groupId != nil ? UserDefaults(suiteName: groupId)! : UserDefaults.standard
    
    public init() {}
    
    public static func fetchSettings() -> Settings {
        guard let encodedSettings = userDefaults.data(forKey: settingsKey) else {
            return Settings()
        }
        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(Settings.self, from: encodedSettings)
            return settings
        } catch {
            print("Error decoding settings - \(error)")
            return Settings()
        }
    }
    
    public func heartbeat(){
        fatalError("This method must be overridden in a subclass")
    }
    
    func stopHeartbeat() {
        pingTimer?.cancel()
        pingTimer = nil
    }
    
    public func connect(){
        fatalError("This method must be overridden in a subclass")
    }
    
    public func disconnect() {
        fatalError("This method must be overridden in a subclass")
    }
    
    public func retry(after delay: DispatchTimeInterval, error: NWError?) {
        fatalError("This method must be overridden in a subclass")
    }
    
    public func cancelRetry() {
        fatalError("This method must be overridden in a subclass")
    }
    
    public func reconnect() {
        fatalError("This method must be overridden in a subclass")
    }
    
    public func receiveData() {
        fatalError("This method must be overridden in a subclass")
    }
    
    func requestNotification(payload: String) {
        if payload.isEmpty { return }
        guard let data = payload.data(using: .utf8) else { return }

        let pong: PongModel? = try? JSONDecoder().decode(PongModel.self, from: data)
        if pong?.pong != nil {
            return
        }
        
        if payload == "reconnect" {
            let content = UNMutableNotificationContent()
            content.title = ""
            content.body = ""
            content.sound = .default
            content.userInfo = [
                "payload": "reconnect"
            ]
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("submitting error: \(error)")
                    return
                }
            }
        }
        
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else {
            return
        }
        
        let appState = Self.userDefaults.bool(forKey: Self.appStateKey)
        
        if !appState && message.notification.Title.isEmpty {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = message.notification.Title
        content.body = message.notification.Body
        if !message.notification.Title.isEmpty {
            content.sound = .default
        } else {
            content.sound = nil
            if #available(macOS 12.0, *) {
                content.interruptionLevel = .passive
            }
        }
        content.userInfo = [
            "payload": payload
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("submitting error: \(error)")
                return
            }
        }
    }
    
    /// for debug
    public func requestNotificationDebug(payload: String) {
        let content = UNMutableNotificationContent()
        content.title = payload
        content.body = "debug"
        content.sound = .default
        content.userInfo = [
            "payload": payload
        ]
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("submitting error: \(error)")
                return
            }
        }
    }
}
