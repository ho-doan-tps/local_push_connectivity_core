public struct Settings: Codable, Equatable {
    public var ssid: [String]? = nil
    public var host: String? = nil
    public var deviceId: String? = nil
    public var connectorID: String? = nil
    public var connectorTag: String? = nil
    public var systemType: Int? = nil
    public var port: Int? = nil
    public var wss: Bool? = nil
    public var wsPath: String? = nil
    public var useTcp: Bool? = nil
    public var publicKey: String? = nil
    public var apnsToken: String? = nil
    public var serverApnsType: Bool? = nil
    public var applicationID: String? = nil
    
    public init() {}

    public init(ssid: [String]?, host: String?, deviceId: String?, connectorID: String?, 
      systemType: Int?, port: Int?, wss: Bool?, wsPath: String?, useTcp: Bool?, 
      publicKey: String?, connectorTag: String?, apnsToken: String?, serverApnsType: Bool?, applicationID: String?) {
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
        self.apnsToken = apnsToken
        self.serverApnsType = serverApnsType
        self.applicationID = applicationID
    }
}
