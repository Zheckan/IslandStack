import Darwin
import Foundation

enum TerminalMenuError: Error, CustomStringConvertible {
  case cancelled
  case inputEnded

  var description: String {
    switch self {
    case .cancelled: "Cancelled."
    case .inputEnded: "Input ended. Run install with --device and --competitors to skip the prompts."
    }
  }
}

enum TerminalMenu {
  static func choose(_ prompt: String, options: [String]) throws -> Int {
    precondition(!options.isEmpty)
    let choice: Int
    if isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1,
       ProcessInfo.processInfo.environment["TERM"] != "dumb" {
      choice = try chooseWithArrows(prompt, options: options)
    } else {
      print(prompt)
      for (index, option) in options.enumerated() { print("\(index + 1). \(option)") }
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
    print("Selected: \(options[choice])")
    return choice
  }

  private static func chooseWithArrows(_ prompt: String, options: [String]) throws -> Int {
    var original = termios()
    guard tcgetattr(STDIN_FILENO, &original) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var raw = original
    cfmakeraw(&raw)
    raw.c_oflag = original.c_oflag
    guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    defer {
      tcsetattr(STDIN_FILENO, TCSANOW, &original)
      write("\u{1B}[?25h")
    }

    write("\(prompt)\nUse ↑/↓ to move, Enter to select, Esc or Ctrl+C to cancel.\n\u{1B}[?25l")
    var selected = 0
    var redraw = false
    while true {
      if redraw { write("\u{1B}[\(options.count)A") }
      var size = winsize()
      _ = ioctl(STDOUT_FILENO, TIOCGWINSZ, &size)
      let width = size.ws_col > 4 ? Int(size.ws_col) - 3 : 77
      for (index, option) in options.enumerated() {
        write("\r\u{1B}[2K\(index == selected ? ">" : " ") \(String(option.prefix(width)))\n")
      }
      redraw = true
      // Consume ignored keys without repainting the menu.
      while true {
        guard let key = try readByte() else { throw TerminalMenuError.cancelled }
        switch key {
        case 10, 13: return selected
        case 3, 4: throw TerminalMenuError.cancelled
        case 27:
          guard let prefix = try readByte(timeout: 150), prefix == 91 || prefix == 79,
                let arrow = try readByte(timeout: 150) else { throw TerminalMenuError.cancelled }
          if arrow == 65 { selected = (selected + options.count - 1) % options.count }
          else if arrow == 66 { selected = (selected + 1) % options.count }
          else { continue }
        default: continue
        }
        break
      }
    }
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
