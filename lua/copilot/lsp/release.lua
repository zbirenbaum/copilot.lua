---@class copilot_release_asset
---@field filename string
---@field sha256 string
---@field entrypoint string

return {
  version = "1.547.0",
  assets = {
    ["darwin-arm64"] = {
      filename = "copilot-language-server-darwin-arm64-1.547.0.zip",
      sha256 = "6601dadbf686505b28002c99f2968211fd8fd1a9fe72dd884103b2ef4d9c4a7a",
      entrypoint = "copilot-language-server",
    },
    ["darwin-x64"] = {
      filename = "copilot-language-server-darwin-x64-1.547.0.zip",
      sha256 = "fa092fa9127a6902c760befc0b40ad2361fcd6c5c6aa929a0f360c8452f2092c",
      entrypoint = "copilot-language-server",
    },
    js = {
      filename = "copilot-language-server-js-1.547.0.zip",
      sha256 = "237c25bd157990b5cb78b255de21abd3c4d85ef29dbdf73fca0dfc5df3d48a91",
      entrypoint = "language-server.js",
    },
    ["linux-arm64"] = {
      filename = "copilot-language-server-linux-arm64-1.547.0.zip",
      sha256 = "eff76d913cf2785c0b063dfe00c4cfb49dfefa1b8d5f9bfaa7c79ac9e2e82439",
      entrypoint = "copilot-language-server",
    },
    ["linux-x64"] = {
      filename = "copilot-language-server-linux-x64-1.547.0.zip",
      sha256 = "ef09049df1028605c3496f7b2ad154664ef1376a231ea4d1345286d965cb8b61",
      entrypoint = "copilot-language-server",
    },
    ["win32-arm64"] = {
      filename = "copilot-language-server-win32-arm64-1.547.0.zip",
      sha256 = "25e5abb98da320017dcf1dd473439f7d721e371c119c09152ae56e323a6d02e3",
      entrypoint = "copilot-language-server.exe",
    },
    ["win32-x64"] = {
      filename = "copilot-language-server-win32-x64-1.547.0.zip",
      sha256 = "99bc342c4a9b84d58ded6bf38b83f231819fe0c8c43054841009bc25724be04a",
      entrypoint = "copilot-language-server.exe",
    },
  },
}
