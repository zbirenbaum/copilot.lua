---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.569.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.569.0.zip",
      sha256 = "929df96da051c6dcac5c127ed610433a37e5032d86d40f0fcb3c6a44ed2cc1ad",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.569.0.zip",
      sha256 = "fb8ce6a48ce27b24ff69c4478eca659e85e3bab9afcf342c8867aea7e135903b",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.569.0.zip",
      sha256 = "4debbb06590a2ac3c555d6260641a7380dee21b8ed35152e592996ab0716d01f",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.569.0.zip",
      sha256 = "f5b72e3fd206950c2de9a2e73e35c8b4a6f7f79e407a0f8c7d27ea65bfe3698d",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.569.0.zip",
      sha256 = "fb4c315e01265ad32f0d1fb43df75e4ed81fa501461c1161942a7488df40e757",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.569.0.zip",
      sha256 = "e453f5156e308e63f900228460bbc4bee8d48cb93acb3af5236e86272b8ce4f0",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.569.0.zip",
      sha256 = "48604cd27b5d6d316a861a62e0e39be5a639169fb8056fab7b446a640c3f69e6",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
