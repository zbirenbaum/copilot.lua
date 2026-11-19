---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.573.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.573.0.zip",
      sha256 = "e326ef360cf1fac95ee2bded4f9efe081dc1a9c81f58c3e5de979e0f82d38196",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.573.0.zip",
      sha256 = "9224ab3d261649ddc2180832fdf071c78299a9ba087cc10b78ec179f73bd7b58",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.573.0.zip",
      sha256 = "062c8b030be81409d4ef0474f2329bf3f21aeb5787d4695eb28f8dde7890dc3a",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.573.0.zip",
      sha256 = "c6d777f92e26cbb387463bdca4d6a807ba4ab8bd3fd589b1ecd13bca87469d76",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.573.0.zip",
      sha256 = "72de86365fd9bc7a622746053d1f8ea9c15ae879b6f211ce819b5e7cd05f7e9e",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.573.0.zip",
      sha256 = "9eb137a3a621c2c708d2ed9ab2c716671e1aceaace2b29851d369b6e334e0629",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.573.0.zip",
      sha256 = "1be3a47d6a9b8b285fa77d674783bee9afd038abf66bcc3990b34a5c29e5ffa8",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
