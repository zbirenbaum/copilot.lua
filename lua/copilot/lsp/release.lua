---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.574.2",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.574.2.zip",
      sha256 = "885c533d14dcf169a23af4abfbd97b3e6b0f76d5f835de9d3f8f04116897c69a",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.574.2.zip",
      sha256 = "b76ea905e002f882f9a3789dedaa884f268b772b798697eaebfca0ea3cc71546",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.574.2.zip",
      sha256 = "ebe8395187243600a99a48e7f6cc0f8fac60b9094d2f0a4730f69e3135ba4f96",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.574.2.zip",
      sha256 = "366e94f182ec7761304f9180f019cc3ee8d01a41eccce14c10acd833ed795ce9",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.574.2.zip",
      sha256 = "00531dba1098dfcfe986902366cd04d870227d387a6b4f9d0e720b42b85902ea",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.574.2.zip",
      sha256 = "81e4e376f366aff871687e7eac3ebfee3915b587083028c879b696342131e810",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.574.2.zip",
      sha256 = "f794f2f4662b1cbdeb43f1fe1c06f1253c76232e9080a1cad014e926f93e74fb",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
