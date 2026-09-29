---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.551.2",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.551.2.zip",
      sha256 = "56d45abf26a8f58913f40a347f09a6ba2aa030d46a127a227e4fe6e85cbb1fae",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.551.2.zip",
      sha256 = "fa31aba3a4a608a3bf6c7557a101f31f004e03d6b186870b19ab92e7c203028c",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.551.2.zip",
      sha256 = "310543162b3afea0f8f02a2c919c764945deb2c11f928e081569494a86378104",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.551.2.zip",
      sha256 = "bd2c232c6112dc6d87fff36360e6ecd6d357c8e5dc4ba0ed82646ba5219840ea",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.551.2.zip",
      sha256 = "9c54d39d431bebb50498eb23ccd02b7b688a205105c20f83cfe5e5e487bc896c",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.551.2.zip",
      sha256 = "08af8dbf96c61b1789eecefc024e5b22cf86af09e08c83614376b7caa62e4eb4",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.551.2.zip",
      sha256 = "5aed75fb731bb0c77f6746a33701c4943b92bf6ed9ff8d4737cdd31a4ac11a4e",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
