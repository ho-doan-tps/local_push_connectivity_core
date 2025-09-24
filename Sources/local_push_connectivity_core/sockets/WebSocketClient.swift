import Foundation
import Network

@available(macOS 10.15, *)
public class WebSocketClient: ISocket {
    public private(set) var connection: URLSessionWebSocketTask? = nil
    public override func connect() {
        let settings = Self.fetchSettings()
        var origin = "ws"
        if settings.wss == true {
            origin = "wss"
        }
        let host = settings.host ?? ""
        let port = settings.port ?? -1
        let path = settings.wsPath ?? ""
        guard let url = URL(string: "\(origin)://\(host):\(port)\(path)") else { 
            return
        }
        
        self.state = .connecting
        let configuration: URLSessionConfiguration = .default
        configuration.timeoutIntervalForRequest = 30
        
        let urlSession = URLSession(configuration: configuration)
        let urlRequest = URLRequest(url: url, timeoutInterval: 30)
        
        connection = urlSession.webSocketTask(with: urlRequest)
        connection?.resume()
        self.state = .connected
        
        self.heartbeat()
        
        dispatchQueue.async {
            self.requestNotification(payload: "reconnect")
        }
        
        let register = RegisterModel(messageType: "register", 
            sender: Sender(connectorID: settings.connectorID ?? "", connectorTag: settings.connectorTag ?? "", deviceID: settings.deviceId ?? ""), 
            data: DataRegister(apnsToken: nil, applicationID: nil, apnsServerType: nil), systemType: settings.systemType ?? -1)
        guard let encoded = try? JSONEncoder().encode(register) else {
            self.disconnect()
            return
        }
        let json = String(data: encoded, encoding: .utf8)!
        
        let data = URLSessionWebSocketTask.Message.string(json)
        self.connection?.send(data) { error in
            if let _ = error {
                self.mReconnect()
                return
            }
            self.receiveData()
        }
        
        if self.connection == nil {
            self.mReconnect()
        }
    }
    
    public override func heartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: dispatchPingQueue)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler {
            [weak self] in
            self?.connection?.sendPing { error in
                if let _ = error {
                    self?.mReconnect()
                }
            }
        }
        pingTimer = timer
        timer.resume()
    }
    
    public override func reconnect() {
        if state != .disconnected { return }
        self.disconnect()
        self.retry(after: .seconds(5), error: nil)
    }
    
    private func mReconnect() {
        self.disconnect()
        self.reconnect()
    }
    
    public override func disconnect() {
        dispatchQueue.async { [weak self] in
            guard let self = self, [.connecting, .connected].contains(self.state) else { return }
            self.state = .disconnecting
            self.cancelRetry()
            self.connection?.cancel()
            self.stopHeartbeat()
            self.connection = nil
            self.state = .disconnected
        }
    }
    
    public override func retry(after delay: DispatchTimeInterval, error: NWError?) {
        retryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !(self.retryWorkItem?.isCancelled ?? true)
            else { return }
            print("retrying to connect with remote server...")
            requestNotificationDebug(payload: "retrying connect....")
            self.connect()
        }
        retryWorkItem = workItem
        dispatchQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    public override func cancelRetry() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }
    
    public override func receiveData() {
        self.connection?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("ws error: \(error.localizedDescription)")
                self.mReconnect()
            case .success(let message):
                switch message {
                case .data(let data):
                    self.receiveData()
                    dispatchQueue.async {
                        let str = String(data: data, encoding: .utf8)
                        self.requestNotification(payload: str ?? "")
                    }
                case .string(let message):
                    self.receiveData()
                    dispatchQueue.async {
                        self.requestNotification(payload: message)
                    }
                @unknown default:
                    print("ws error receive: \(result)")
                    self.mReconnect()
                }
            }
        }
    }
}
