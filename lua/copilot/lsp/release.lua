---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.561.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.561.0.zip",
      sha256 = "fa1d9d3995d33c877233324ec3953cdaafa31ea884eff27b714c98abfa8f1e7e",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.561.0.zip",
      sha256 = "5c2cc26b0d346d15247d504792190dcf9fc8792f378ac1a7a7766efcb9623707",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.561.0.zip",
      sha256 = "cc6879b61d6ee0779addbde37f5437f4c00bc4986888d48d93df4174eded8818",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.561.0.zip",
      sha256 = "d0002a22df152ff47c4f66b7c0f7243ff1a2b833c3f7eae6f9a4174c6a31ee2e",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.561.0.zip",
      sha256 = "caf0931c0a799b37683b4c0dcb7e9304d77896a43766d6a6095157bbeebd48bd",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.561.0.zip",
      sha256 = "06af340b32f2581504309dcbb25b0cb97f9fa89826e45417208c805f88a6a298",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.561.0.zip",
      sha256 = "fd36b920bc149a728d599576a94217a1aa2771098206f7fae1d7870e481a8213",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
