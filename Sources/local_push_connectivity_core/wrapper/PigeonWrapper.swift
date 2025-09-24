public struct Settings: Codable, Equatable {
    var ssid: [String]? = nil
    var host: String? = nil
    var deviceId: String? = nil
    var connectorID: String? = nil
    var connectorTag: String? = nil
    var systemType: Int? = nil
    var port: Int? = nil
    var wss: Bool? = nil
    var wsPath: String? = nil
    var useTcp: Bool? = nil
    var publicKey: String? = nil
    
    public init() {}

    public init(ssid: [String]?, host: String?, deviceId: String?, connectorID: String?, 
      systemType: Int?, port: Int?, wss: Bool?, wsPath: String?, useTcp: Bool?, publicKey: String?, connectorTag: String?) {
        self.ssid = ssid
        self.host = host
        self.deviceId = deviceId
        self.connectorID = connectorID
        self.connectorTag = connectorTag
        self.systemType = systemType
        self.port = port
        self.wss = wss
        self.wsPath = wsPath
        self.useTcp = useTcp
        self.publicKey = publicKey
    }
}
