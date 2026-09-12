---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.545.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.545.0.zip",
      sha256 = "781198251e940eb0cacaac8af1a45a5725e09bc50b080bee8ab32a8e810c9b20",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.545.0.zip",
      sha256 = "5df00ec2cc94c0cbcc5ed1e43d75b6da2c9a465b1f43266f33eda431e9261b7b",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.545.0.zip",
      sha256 = "24cc1ed4815077b1f3e92b15f85c8ae1a039d621d2e6eadabdfea2c6037a86e6",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.545.0.zip",
      sha256 = "fffe8186b26b661d03f12fd909d2e19f53feea8a6c6160ae3968b9d6fc70246b",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.545.0.zip",
      sha256 = "8cd23a68de4676340b12605f9efa734ff9989df26e753aa8305a16bd0bff885b",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.545.0.zip",
      sha256 = "a4b7cc478e526645feab37ea8889b60001e63200da590059f883628cc8187faf",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.545.0.zip",
      sha256 = "c85f6c69ed418efe27046c89b195fc407cd8c4941056d75ef2e693e1ab541252",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
