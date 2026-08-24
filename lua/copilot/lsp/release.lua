---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.534.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.534.0.zip",
      sha256 = "d449a75bc3f286c07f153136eb959679fc585cb905685c23778fbffa977757bc",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.534.0.zip",
      sha256 = "247e939888e1bde79bc7bc342d8949bd0ec2040571e08ae3810312f519049e34",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.534.0.zip",
      sha256 = "58cdccb2a9db11852d214d269d3c6a70fb41908c820de652f0126340cdc419cb",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.534.0.zip",
      sha256 = "2e20e6b177b46f559c6e48b40c7b7c30a55bf9c0aea14b80a653409861744370",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.534.0.zip",
      sha256 = "27cca080df4d911b3d282523ff54df43f52a7d7709b490025352742a5519a257",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.534.0.zip",
      sha256 = "e445163c45cd634fa6e910b8cf86f499ec2bc274e58ae65b473c808ece6ec7a2",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.534.0.zip",
      sha256 = "86051587b9d82506d3e0acb678272aa6c4a5e4af6f2f0e02fad3456cc88a48ba",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
