---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.553.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.553.0.zip",
      sha256 = "b4d6fbfa7cb892edb310cecc17aa48de0f998dc2537332826d44e90edda00bc2",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.553.0.zip",
      sha256 = "e5c1c68f224fb545cce6012096e7e72f5d67aefc429344ec057dc20e4a83f097",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.553.0.zip",
      sha256 = "bf861a32a940f24c89b67f50da37b345fe110c4523e80fc2212dfe3f75dd164d",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.553.0.zip",
      sha256 = "f37d6ebf11c99ff52b3e49bcdd4490cffc9b1aa287455ef553eadc7c965ed71f",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.553.0.zip",
      sha256 = "3345dd63b7cde538b9aa40f67147ac8da27bffa6df4ac99bbc0ede9864ddd698",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.553.0.zip",
      sha256 = "6119fd6c1f0797735aa229bb1bb6202fe41388ad871f8ef14e7abee3348d9b60",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.553.0.zip",
      sha256 = "8a6769939b46b959487f673438794995062a23351cddbcf0e5e1cad48f7bc464",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
