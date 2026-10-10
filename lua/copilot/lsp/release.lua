---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.552.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.552.0.zip",
      sha256 = "2bda991654f9f23173224f14ab477af8c01d4b6071e495671d8b5da4386e9649",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.552.0.zip",
      sha256 = "e87a5252fc7f49d221984838ffcb7ee4f4254a501fdb5390cb80229c9b4b0c7d",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.552.0.zip",
      sha256 = "1c2834904106f5a88f4b2f20224e4b22955583997409e4252fe3231af583eeb3",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.552.0.zip",
      sha256 = "9328ac3a815ae9a924437fa200f74052b4369ea7bce9498f758774342fff3ad5",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.552.0.zip",
      sha256 = "f941950a2497740b3ceee1b43a0ec7f19077c23e96e6521dae0a8e54d567a2f7",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.552.0.zip",
      sha256 = "5b865c8aaa075eeed159ad695efa7c23d57b03659960623a3492ce6f506c3125",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.552.0.zip",
      sha256 = "20fc3ba0fa5974e46206e33f978fba40f1c86d7a7455f1a8d9be8e772e190cec",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
