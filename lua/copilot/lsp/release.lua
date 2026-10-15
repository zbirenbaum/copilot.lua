---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.554.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.554.0.zip",
      sha256 = "d5ba2bf881353a9791ab341397cbde0acdecb43de14c6dbcfba7571801bb3ae1",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.554.0.zip",
      sha256 = "1eb51f1a05746ba9206ad9c6c0fde1bd910c025cbbc77e094dc07227f8d4f2b3",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.554.0.zip",
      sha256 = "021e71edece5cc3c02d2b21625ab37c32f4d26deb3dfcef29006e7a289b629aa",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.554.0.zip",
      sha256 = "12b6b2df64987ffb42c79cab409cdc6f0e239b56d04569a2e29cc0d107febfc3",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.554.0.zip",
      sha256 = "f87d67b12986bfb8106cd19fef79b80a423bc1012975c8f380bcd164a753b541",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.554.0.zip",
      sha256 = "6a89ed35f886527d3fef17eedad69c65aaa742fa2070fa7e4d1dee200850a668",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.554.0.zip",
      sha256 = "0e7ba17e16ae70fdf4e0410b5f4a32d8fc4552aec65958abf60a91b707741c34",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
