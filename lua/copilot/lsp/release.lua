---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.558.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.558.0.zip",
      sha256 = "337eb72ac44e6fc2f6e839ec298d1d311aa895312b57e761caafc1af738f5b9a",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.558.0.zip",
      sha256 = "4425d3a87ed69d2b645dc33a17e4c637d8f2f11e8b98ae3963a4e33f29250ff7",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.558.0.zip",
      sha256 = "6d3c5354cd56a46d9543a4f8829eb3bc02073b6081555f1a8593acf2597b0579",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.558.0.zip",
      sha256 = "d3273f3bbff29c03fe4417a5a568e64db34c3d799fe91c69c1d6b702cd8baa2e",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.558.0.zip",
      sha256 = "3fe6d39b7c33bcca6769b712100e3ceb0970fd17b7fc1e9cb81a43649cfe76d6",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.558.0.zip",
      sha256 = "b3f4de65139c61fc8f2ffbe80880892f8033da6a29f357dc4fd5cd56c505e474",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.558.0.zip",
      sha256 = "ded87835e821f121d0e172bb12ae68fa01182ca67fb71e0909eb4e4ad1772c9d",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
