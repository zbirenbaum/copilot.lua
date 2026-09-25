---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.551.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.551.0.zip",
      sha256 = "323af766d32e2d81ae2f4b80d51ad05b2a672bd895a4e381dd07972b80cf8f2d",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.551.0.zip",
      sha256 = "e7c1c80d9149c731e6a782d73e8be515f09c9cb34bbc3ec4b198821cbedc336e",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.551.0.zip",
      sha256 = "4ffa3e996f88368472e68ef66b4617f9b38a9d20b63d3b7c25aa9cd8cdca407b",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.551.0.zip",
      sha256 = "aed43f4c70f678aa71881a9e048226397e637354c139cee5c820475010e49291",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.551.0.zip",
      sha256 = "bc84b917b64cd138b927847cfb203715223905809ef8006db1a8219990610eac",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.551.0.zip",
      sha256 = "ba02bf0cea1f293bacb09a6b4a668747259a79ab7f7e7687090d3993e531dc09",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.551.0.zip",
      sha256 = "4c47028ee492396e00f5bac5a3cf582a09708c2e89b0a62a400d60b0fb763e31",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
