---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.575.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.575.0.zip",
      sha256 = "04d3124da988a4e45809ac086bb84956e34c2e5ca867a705b21fd677267df401",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.575.0.zip",
      sha256 = "159a9fdc478e6cc599f966dcb68e79c9caf5b5bc73467c98f88a1e2785799e66",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.575.0.zip",
      sha256 = "ae20955034cf1679844f5df269be50f9abe8c18e755867e4ce67d2fb4ed8925a",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.575.0.zip",
      sha256 = "6afcbad43c91d7db53f403a7c1c860a63ec89dbed108da18b4e441e940f08daa",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.575.0.zip",
      sha256 = "27a1cd4a3097cec8a087555e4f83bba40e380df0c558ff377ffa1ebe772ad8b7",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.575.0.zip",
      sha256 = "1816294b49452298d755b9363b1ca3bffeb7c1b41292ab2a19a8dfb5875cfa53",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.575.0.zip",
      sha256 = "22e09f506751db181441999af7ba68a883c4e215771e15e4bc57146f7d67a179",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
