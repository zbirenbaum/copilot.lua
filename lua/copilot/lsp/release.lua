---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.560.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.560.0.zip",
      sha256 = "6dc699b21165ae6edc8721254dee20bf23462f7fb225035204b11bb983d3c9ae",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.560.0.zip",
      sha256 = "c995e4fc715dc14ab57a821c0390eacc64580aa916ecd1d41e060da73bebdd05",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.560.0.zip",
      sha256 = "bfbdcc0dab5e777aebe796f9b6991e1475414d30b9ae80c24954d542fe4c76cf",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.560.0.zip",
      sha256 = "dc11c84ee91f25c86fc83ab05facc7edf43d1c6125ad2df83204e8f9da3ca260",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.560.0.zip",
      sha256 = "a307faf7c3ce7774ad1a8b4c73d1649ab8e0e83837acc57338a932368b3731d9",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.560.0.zip",
      sha256 = "c97410dfd95560f3e802948215bd2eb1498a2a1a25d2f3791048b871b644e737",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.560.0.zip",
      sha256 = "a33899488c71cd96e527dd50ef0c163356f26b5c43a1189cff6d2398cad2c27d",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
