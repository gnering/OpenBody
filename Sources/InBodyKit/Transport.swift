import Foundation

/// Transporte da balanca sobre um descritor (fd): serve para TCP (WiFi/rede) e para
/// SERIAL (dongle Bluetooth do InBody, que aparece como /dev/cu.* no Mac). O protocolo
/// InBody e o MESMO nos dois; so muda como o fd e criado. Original: dongle = ponte
/// Bluetooth->serial a 115200 8N1 ASCII (LB.Commnuication.Bluetooth: BaudRate=115200,
/// "SET CONTROL BAUD 115200,8N1", Handshake=None nos dados).
public final class PortTransport {
    private let fd: Int32
    private let ehSerial: Bool
    private var rxBuffer: [UInt8] = []

    /// Conexao por REDE (WiFi/LAN), porta 2004/2005.
    public init?(host: String, port: UInt16, timeoutMs: Int = 400) {
        fd = socket(AF_INET, SOCK_STREAM, 0)
        ehSerial = false
        if fd < 0 { return nil }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if ok != 0 { close(fd); return nil }
        var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Conexao SERIAL (dongle Bluetooth / cabo). `device` = /dev/cu.usbserial-XXXX.
    /// Configura termios: baud (115200), 8 bits, sem paridade, 1 stop, raw, sem controle
    /// de fluxo por hardware (dados = Handshake None no original).
    public init?(serialDevice device: String, baud: speed_t = speed_t(B115200)) {
        // O_NONBLOCK na abertura: nao trava se nao houver "carrier"; depois volta a blocking.
        fd = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK)
        ehSerial = true
        if fd < 0 { return nil }
        var t = termios()
        if tcgetattr(fd, &t) != 0 { close(fd); return nil }
        cfsetispeed(&t, baud)
        cfsetospeed(&t, baud)
        t.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
        t.c_cflag &= ~tcflag_t(PARENB)                 // sem paridade (N)
        t.c_cflag &= ~tcflag_t(CSTOPB)                 // 1 stop bit
        t.c_cflag &= ~tcflag_t(CRTSCTS)                // sem RTS/CTS (dados)
        t.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)   // raw
        t.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY | ICRNL | INLCR)
        t.c_oflag &= ~tcflag_t(OPOST)
        // leitura com timeout curto: VMIN=0, VTIME=2 (0,2s) -> read retorna sozinho
        withUnsafeMutablePointer(to: &t.c_cc) {
            $0.withMemoryRebound(to: cc_t.self, capacity: 20) { cc in
                cc[Int(VMIN)] = 0
                cc[Int(VTIME)] = 2
            }
        }
        if tcsetattr(fd, TCSANOW, &t) != 0 { close(fd); return nil }
        _ = fcntl(fd, F_SETFL, 0)   // tira O_NONBLOCK: reads passam a respeitar VMIN/VTIME
    }

    public func write(_ bytes: [UInt8]) {
        _ = bytes.withUnsafeBytes { Foundation.write(fd, $0.baseAddress, bytes.count) }
    }

    public func readSome(_ n: Int = 512) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: n)
        let r = Foundation.read(fd, &buf, n)
        return r > 0 ? Array(buf[0..<r]) : []
    }

    /// Extrai UM quadro (STX..ETX) do buffer, guardando a sobra (quadros grudados).
    private func extractFrame() -> [UInt8]? {
        guard let stx = rxBuffer.firstIndex(of: InBodyProtocol.STX) else {
            rxBuffer.removeAll(keepingCapacity: true)
            return nil
        }
        if stx > 0 { rxBuffer.removeFirst(stx) }
        guard let etx = rxBuffer.firstIndex(of: InBodyProtocol.ETX) else { return nil }
        let frame = Array(rxBuffer[0...etx])
        rxBuffer.removeFirst(etx + 1)
        return frame
    }

    /// Le ate um ETX. Quadro cru; quadros extras ficam no buffer.
    public func readFrame(timeout: TimeInterval = 6) -> [UInt8]? {
        if let f = extractFrame() { return f }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let chunk = readSome(4096)
            if chunk.isEmpty {
                if ehSerial { usleep(5_000) }   // serial nao-bloqueante: evita busy-spin
                continue
            }
            rxBuffer.append(contentsOf: chunk)
            if let f = extractFrame() { return f }
        }
        return nil
    }

    /// Portas seriais candidatas (dongle Bluetooth / cabo) no Mac: /dev/cu.*.
    public static func portasSeriais() -> [String] {
        let dev = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        // Portas internas do macOS que NÃO são balança: entrada Bluetooth, console de debug, wlan-debug.
        let lixo = ["bluetooth-incoming", "debug", "wlan"]
        return dev.filter { $0.hasPrefix("cu.") }
            .filter { nome in !lixo.contains { nome.lowercased().contains($0) } }
            .map { "/dev/\($0)" }
            .sorted()
    }

    deinit { close(fd) }
}

/// Compatibilidade: o nome antigo continua valendo (LiveTest usa TCPTransport(host:port:)).
public typealias TCPTransport = PortTransport

/// Aperto de mao completo P0/P1, igual ao do LookinBody — por rede OU por serial.
public struct InBodySession {
    public let transport: PortTransport

    public init?(host: String, port: UInt16) {
        guard let t = PortTransport(host: host, port: port) else { return nil }
        self.transport = t
    }

    /// Sessao pela porta serial (dongle Bluetooth / USB / cabo do InBody).
    public init?(serialDevice device: String, baud: speed_t = speed_t(B115200)) {
        guard let t = PortTransport(serialDevice: device, baud: baud) else { return nil }
        self.transport = t
    }

    @discardableResult
    public func handshake() -> (deviceInfo: String, passed: Bool)? {
        transport.write(InBodyProtocol.makeFrame("P", "0", "NEWPROTOCOL\u{1B}"))
        guard let raw = transport.readFrame(),
              let (payload, crcP0) = InBodyProtocol.parse(raw),
              let code = InBodyProtocol.securityCode(payload) else { return nil }
        if !crcP0 { InBodyLog.warn("CRC do P0 nao confere") }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMddHHmmss"
        let stamp = fmt.string(from: Date())
        usleep(140_000)
        transport.write(InBodyProtocol.makeFrame("P", "1", code + "\u{1B}" + stamp + "\u{1B}"))
        guard let raw2 = transport.readFrame(),
              let (p2, crcP1) = InBodyProtocol.parse(raw2) else { return nil }
        if !crcP1 { InBodyLog.warn("CRC do P1 nao confere") }
        return (payload, !p2.uppercased().contains("FAIL"))
    }
}
