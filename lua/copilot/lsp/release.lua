---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.548.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.548.0.zip",
      sha256 = "37e46fc2623cadf45fea254ea18c4f0c546ff397b45b99b2fa82bd2145d7d728",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.548.0.zip",
      sha256 = "dafec516dfd0730c6494f769ea614b89d33db9411feef5ead72dcb1565e165ce",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.548.0.zip",
      sha256 = "831c3f3e9f7c8935d2948fa5b4591cd667c3652fd8a6416f92730f6eaee79959",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.548.0.zip",
      sha256 = "8cc5613aa6e65217a921d8c7deba7325b89f550f571ccde9d73a46af2ab5dc36",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.548.0.zip",
      sha256 = "a51d719a02de202a36bc97ef5478bc3564e909f4ebd33b4da823f71adeaad5bb",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.548.0.zip",
      sha256 = "202b6a5e0048a68502cc75fdd1e9dfd48fab541aebf086ac4d26efe28df09153",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.548.0.zip",
      sha256 = "8b65e4362382f6f746676746e2ad1fac3934626e64ec3287efdaa4280c44ab07",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
