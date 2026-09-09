---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.543.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.543.0.zip",
      sha256 = "94ba8f0da833fa6559750b2a1110fb24c1af25e43298d979b0e54ff6d841a3f2",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.543.0.zip",
      sha256 = "e79946ca602b3590e64246ce431b5503c696873a871461846f6703e553afdd95",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.543.0.zip",
      sha256 = "032016c5fe1a07878d03b5e88ef3e192ed7f9d3ebaad7a66094f75b6056787cb",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.543.0.zip",
      sha256 = "85b7b8d96bf0b73e5882604723bc808bcb37ca97772376b593d36885b057dbac",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.543.0.zip",
      sha256 = "81785f12e249cd32f3d4df17bea251920cae4d15dcd3933264ae472eb72b0f26",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.543.0.zip",
      sha256 = "9ac91622bb706c8b283fcba0990a44179448035d1e291f94f2b6aa61b7991f0c",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.543.0.zip",
      sha256 = "70702ff89e2fc4017d475e38849ea22720eb853d2539fe1b15953fbb6746ba1b",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
