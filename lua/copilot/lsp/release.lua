---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.544.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.544.0.zip",
      sha256 = "d9723c17f64657fd66d845285f79ce8aaac9204e33a218090a45c2dc0f9f8cd9",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.544.0.zip",
      sha256 = "ea7cd4460970e229b120fc0d4665aa00d5909bc3d43e196318076228e6afc2b9",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.544.0.zip",
      sha256 = "c066734e3e3f3fd4c31c45e76939b424831a3db93d0e976724f59970d2661d8c",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.544.0.zip",
      sha256 = "1484af9f90233d1e7a8bbed0523497edf9ef31d36b9fe3a1ce82a08f8c2007a9",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.544.0.zip",
      sha256 = "420029d44839f1684519e21d5f51d4a81dca8488bacbff9835b9e8faeb6ab676",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.544.0.zip",
      sha256 = "0a4631dca7c2a09bf7f19744fc8e3c1a5f890b84b70c6e53f8ece236a3e9b331",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.544.0.zip",
      sha256 = "f68bd0006442224f5e3bcfe858899bb2474ddd847a3843da388eb5369d6d2991",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
