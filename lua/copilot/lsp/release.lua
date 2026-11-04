---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.566.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.566.0.zip",
      sha256 = "bee57e3e046e072e0bf227229294e88b940c093b5fc12309b4b7986d4d9f259a",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.566.0.zip",
      sha256 = "cc8f4a54f21ae3fa813d531563e6036a957d64ea8d596d8d53aff25c7978773b",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.566.0.zip",
      sha256 = "c943c9dbb2d94068e906c2834e28e67a4e84d6849ed42ce4e980935b4b5d5d5c",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.566.0.zip",
      sha256 = "0e6db1f76ec1afc5019b612f2eedab394b0df7b2ce22637547212eec16c25cb6",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.566.0.zip",
      sha256 = "ffdaffed4d8bc05b31042b2d991bdeca5d262c33ba9761df6fc0b9c184c051f8",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.566.0.zip",
      sha256 = "b94caaa94ba5d2c50b0cdb0c345088590d4c4f7e003be4caddb2f1889da417c8",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.566.0.zip",
      sha256 = "1236fe4f67f2847722d40268962ed867048346f42451983cbb64ab21e9297e4c",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
