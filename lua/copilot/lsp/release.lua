---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.571.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.571.0.zip",
      sha256 = "8e142f65733cc056d9b528edfecac95c5b1f72940d1d3072096371661be75a06",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.571.0.zip",
      sha256 = "1c825822ab017498baf7559bddca6e8d9d48e85be0cef9b054af22a6c5253e8a",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.571.0.zip",
      sha256 = "3498d4a6982b7ff78e54afecc43e7cb6f706db9937eea7a83140612c8efc399c",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.571.0.zip",
      sha256 = "60868d43b2b46c106f620540bfdab69616608034b9a0f89dff1e38236c49bd4d",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.571.0.zip",
      sha256 = "5e612eafaa560725b4c7f03ff69805add6ba257a70b9206765a7a7ed34af8fd5",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.571.0.zip",
      sha256 = "264963b937115a9425e941c3a7341fc5d1d5c249ff63724e045d68b81c5d1e70",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.571.0.zip",
      sha256 = "7aab8389d96d6f322f6d70962f4bf9c59eccf64796b8451a8d0e09c6377db54b",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
