---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.527.5",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.527.5.zip",
      sha256 = "9d6a5bd9172f4c6ad916aec7fcbc463d5700ef1c2210f0bf6a6a981c44558d74",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.527.5.zip",
      sha256 = "ae0a2fc957dbbcb2963e29f84dce30f5aa223673da3eeec733144987702d2eb4",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.527.5.zip",
      sha256 = "3dc75ab0f0baac2764c44fd67d91e298ca23f7705e74198061beb8a69e0b6f5b",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.527.5.zip",
      sha256 = "e154a2aad5429e3b6ac8ccddac9036948d69913d91f5fc928a96aa414e4ab2b6",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.527.5.zip",
      sha256 = "091c8e667b5a96035a589952a774d6b1dc9ceca14bc61ef985869bc0db571660",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.527.5.zip",
      sha256 = "0f2820c07104467fcf029fd5b8979dcff7e162e6e97d9b0ca843bbc7e195415f",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.527.5.zip",
      sha256 = "704f0c217c846eb20b9c0179efebd770513c01d2cd12231c37c1f9586076b320",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
