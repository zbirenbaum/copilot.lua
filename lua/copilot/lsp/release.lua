---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.550.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.550.0.zip",
      sha256 = "56255bf145b7962037c7ef3057656af63e00b213942b1942e8b777a5b158a3a8",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.550.0.zip",
      sha256 = "c2cf71b45b61247f652f673580ae72dd467027ce17b1cd21ada021b26d279df8",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.550.0.zip",
      sha256 = "fc037bb1a29fe385505925ce5942ec3ff21781aad76d928499bfad420c6c67c8",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.550.0.zip",
      sha256 = "a5a2688676b73362895620e09f9c5f9146c71c42d756c8450cb1b91aed1d64fa",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.550.0.zip",
      sha256 = "74b7f0ddde639027d3ca0d505271d82ab1623985a42a9f938bd9d73c35dbd05b",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.550.0.zip",
      sha256 = "a5ba4d39f625ea4191180e3ddfbed3fc4ef1e84c2e17334b96013cc321fa7506",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.550.0.zip",
      sha256 = "f6e13e29ee842b30d3943c3c20da3526d37bac36ad90daaff8abff2affceea72",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
