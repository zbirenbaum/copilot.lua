---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.570.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.570.0.zip",
      sha256 = "0970c54fa11a4e6afd926f46fdce25d76e694b027262daf1599e342065dceef2",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.570.0.zip",
      sha256 = "6a67bb39b47a7cc65c56f1188ad1502cdc57646b3f12e167868894217e0cd893",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.570.0.zip",
      sha256 = "e3ff8853db994d8131c4f0c192ba26f0dd47e3be548bb07725e8d0349f039080",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.570.0.zip",
      sha256 = "47dd660a6dd479d4da4cb8a7f94bc339e99c49553de5d4e78b040b227b928722",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.570.0.zip",
      sha256 = "bd0580ad93098a6e3fce170de255a9b0940c11896e5f78df48c77705b5f51a63",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.570.0.zip",
      sha256 = "565e97db52e0f93fc3bb2b22c1215e27ff0b7074de9c33c7a98eaac9541ab270",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.570.0.zip",
      sha256 = "20b999357ef23db7d0752003d3a20c01ff0488dcdca48c79cc84cd7afbf6b7b3",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
