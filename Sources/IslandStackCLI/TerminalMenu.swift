import Darwin
import Foundation

enum TerminalMenuError: Error, CustomStringConvertible {
  case back
  case cancelled
  case inputEnded

  var description: String {
    switch self {
    case .back: "Return to the previous setup screen."
    case .cancelled: "Cancelled."
    case .inputEnded: "Input ended. Run install with --device and --competitors to skip the prompts."
    }
  }
}

struct TerminalMenuOption {
  let title: String
  let description: String
}

enum TerminalMenu {
  static func choose(_ prompt: String, options: [TerminalMenuOption], initialChoice: Int = 0,
                     allowsBack: Bool = false) throws -> Int {
    precondition(!options.isEmpty)
    let choice: Int
    if isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1,
       ProcessInfo.processInfo.environment["TERM"] != "dumb" {
      choice = try chooseWithArrows(prompt, options: options, initialChoice: initialChoice,
                                    allowsBack: allowsBack)
    } else {
      print(prompt)
      for (index, option) in options.enumerated() { print("\(index + 1). \(option.title)") }
      while true {
        print("Enter a number from 1 to \(options.count).")
        guard let line = readLine() else { throw TerminalMenuError.inputEnded }
        if let value = Int(line.trimmingCharacters(in: .whitespacesAndNewlines)),
           (1...options.count).contains(value) {
          choice = value - 1
          break
        }
      }
    }
    print("Selected: \(options[choice].title)")
    return choice
  }

  private static func chooseWithArrows(_ prompt: String, options: [TerminalMenuOption],
                                       initialChoice: Int, allowsBack: Bool) throws -> Int {
    var original = termios()
    guard tcgetattr(STDIN_FILENO, &original) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var raw = original
    cfmakeraw(&raw)
    raw.c_oflag = original.c_oflag
    guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer {
      tcsetattr(STDIN_FILENO, TCSANOW, &original)
      write("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l")
    }

    write("\u{1B}[?1049h\u{1B}[?25l")
    var selected = min(max(initialChoice, 0), options.count - 1)
    while true {
      render(prompt, options: options, selected: selected, allowsBack: allowsBack)
      // Consume ignored keys without repainting the menu.
      while true {
        guard let key = try readByte() else { throw TerminalMenuError.cancelled }
        switch key {
        case 10, 13: return selected
        case 3, 4, 81, 113: throw TerminalMenuError.cancelled
        case 75, 107: selected = (selected + options.count - 1) % options.count
        case 74, 106: selected = (selected + 1) % options.count
        case 27:
          guard let prefix = try readByte(timeout: 150), prefix == 91 || prefix == 79,
                let arrow = try readByte(timeout: 150) else {
            throw allowsBack ? TerminalMenuError.back : TerminalMenuError.cancelled
          }
          if arrow == 65 { selected = (selected + options.count - 1) % options.count }
          else if arrow == 66 { selected = (selected + 1) % options.count }
          else { continue }
        default: continue
        }
        break
      }
    }
  }

  private static func render(_ prompt: String, options: [TerminalMenuOption], selected: Int,
                             allowsBack: Bool) {
    var size = winsize()
    _ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &size)
    let width = size.ws_col == 0 ? 80 : Int(size.ws_col)
    let height = size.ws_row == 0 ? 24 : Int(size.ws_row)
    func line(_ row: Int, _ text: String, style: String = "") {
      write("\u{1B}[\(row);3H\(style)\(text.prefix(max(0, width - 4)))\u{1B}[0m")
    }
    write("\u{1B}[2J\u{1B}[H")
    guard width >= 44, height >= 18 else {
      line(1, "Resize terminal to at least 44x18.")
      line(3, "Q or Ctrl+C cancels.")
      return
    }
    line(1, "IslandStack setup", style: "\u{1B}[1;36m")
    line(3, prompt, style: "\u{1B}[1m")
    let visibleCount = height - 12
    let offset = max(0, selected - visibleCount + 1)
    for index in offset..<min(options.count, offset + visibleCount) {
      line(5 + index - offset, "\(index == selected ? "●" : "○") \(options[index].title)",
           style: index == selected ? "\u{1B}[1;7;36m" : "")
    }
    line(height - 7, "What this does", style: "\u{1B}[1;36m")
    var row = height - 6
    var text = ""
    for word in options[selected].description.split(separator: " ") {
      if !text.isEmpty, text.count + word.count + 1 > width - 4 {
        line(row, text)
        row += 1
        text = ""
      }
      guard row < height - 2 else { break }
      text += (text.isEmpty ? "" : " ") + word
    }
    if row < height - 2 { line(row, text) }
    line(height - 1, "Use ↑/↓ or J/K to move • Enter confirm", style: "\u{1B}[2m")
    line(height, "Esc \(allowsBack ? "back" : "cancel") • Q or Ctrl+C cancel", style: "\u{1B}[2m")
  }

  private static func readByte(timeout: Int32 = -1) throws -> UInt8? {
    var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    while true {
      let ready = poll(&descriptor, 1, timeout)
      if ready == 0 { return nil }
      if ready < 0 {
        if errno == EINTR { continue }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
      var byte: UInt8 = 0
      let count = Darwin.read(STDIN_FILENO, &byte, 1)
      if count == 1 { return byte }
      if count == 0 { return nil }
      if errno != EINTR { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
  }

  private static func write(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
  }
}
