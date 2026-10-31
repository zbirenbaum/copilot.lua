---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.565.1",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.565.1.zip",
      sha256 = "e85fc4057af320716aea1b5c83cb829deeeff4ba1e61c5b2cba2651e4b09de3f",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.565.1.zip",
      sha256 = "82b7598b1e5daea35061438eac21def22b43c2bd4fde00e0107587ab5f078dbc",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.565.1.zip",
      sha256 = "48e802b938fc1d30da190c0b348347ce953bbb1d68682df75c033c680b95ab04",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.565.1.zip",
      sha256 = "c022f1b06ceffe4d40ea6aed8580d824a82eba5844672c940c56c9d0b57ad615",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.565.1.zip",
      sha256 = "4830c4d017a56d4b6bf37f92927accc15e21753fbf59f48dbd099a5d3872b49e",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.565.1.zip",
      sha256 = "e6a13d42fdeb8eae8587432ca2901a452da9776bca27a5b5f412adba940b8797",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.565.1.zip",
      sha256 = "19fc08da97ba106d6ca063b8d466d5e012e586bd422251ac56f55dc28e422feb",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
