---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.555.2",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.555.2.zip",
      sha256 = "a7682d9a20583b03ea8fd4a68a4323f5743ea529c30addc6f176f62ee54b8915",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.555.2.zip",
      sha256 = "e10d64bc0f45c6fef499f64a0dca084c957dd58ff51cc87c0e1b6a9117e4c06e",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.555.2.zip",
      sha256 = "72ad358d946b8a802824f3024d48abd7c364ee5f78ca44fbbe858ae590f7566f",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.555.2.zip",
      sha256 = "2c7741ccc5b835a9f6a8f7e4043a7cba050d2fa1cb0be3ceb98a6713d738ee8b",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.555.2.zip",
      sha256 = "26da000a5c1367326a461fad3a8b0d009464f146f0870b7ec522ab17d6156933",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.555.2.zip",
      sha256 = "1207dc673398756004de5de0159c8e49b7888894a085005a97850323eff3a471",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.555.2.zip",
      sha256 = "ab15c511db422a6d394bd9a547bc0dcf199c848f7c477abf53b010d3a1e5c31e",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
