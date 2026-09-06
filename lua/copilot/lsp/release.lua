---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.541.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.541.0.zip",
      sha256 = "972ff802cf481909a8dd0865f4a8504e75e5dbb6b6fb2a7f2b1fbc8651d912c9",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.541.0.zip",
      sha256 = "f1e42626652c96022c494ca98290971e12fc9a8a82c3bbb18f923bf077d71491",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.541.0.zip",
      sha256 = "e86dd9dd9295b4be4d93b14febc847590419fee1fb6863c84fcb1a8595bb4479",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.541.0.zip",
      sha256 = "77e5cd73d044270ff055dc55a515a24b40d43ad45a215ad51591854f4cee2cd7",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.541.0.zip",
      sha256 = "22a211f163d6c13c016b832c8a4a2908743eada3695ac68ae5b467c8ab66c3c8",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.541.0.zip",
      sha256 = "f250d710084913d85616353dcc42f4f517ba6d41075ae741f3eaff7f56ace303",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.541.0.zip",
      sha256 = "c226cab5fb9bcc69d20aac538856717ad08d139b9dd3f89e8134739f6043edfb",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
