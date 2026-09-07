---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.542.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.542.0.zip",
      sha256 = "a8780bb5d35a22824cc21af4bbe7c345933a7a2ae8e4225e8671e88edc7b28eb",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.542.0.zip",
      sha256 = "bc95a966eccd8746c03d17bf5078bdc5f88c1e4dd2c382345083bb9344d596d3",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.542.0.zip",
      sha256 = "f65761d4a01c3b847543b2f21b08faad657ecee0f629b12c0c31d02e6670fabc",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.542.0.zip",
      sha256 = "2a2d326068b6cbd6b97af3c6f53f274db4e3f5e0e966f2395b382374cb06e4c8",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.542.0.zip",
      sha256 = "2bc7d9001ac3cf162709c6e09ffdab1e7cd56e363ed11211d0c86a3b92b7c1f1",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.542.0.zip",
      sha256 = "6dc1f91757b66d918066efe22b2d65d78db4b181444b3597e1779a71a50fa401",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.542.0.zip",
      sha256 = "3c366858e94cd17a53048e6e439a7f4c998d397d848a639b77376f40413c69db",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
