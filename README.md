# copilot.lua

This plugin is the pure lua replacement for https://github.com/github/copilot.vim

While using copilot.vim, for the first time since I started using neovim my laptop began to overheat. Additionally, I found the large chunks of ghost text moving around my code, and interfering with my existing cmp ghost text disturbing. As lua is far more efficient and makes things easier to integrate with modern plugins, this repository was created.

## (IMPORTANT) Usage:

Note that this plugin will only start up the copilot server. The current usage of this is via https://github.com/zbirenbaum/copilot-cmp, which turns copilot suggestions into menu entries for cmp, and displays the full text body in a float, similar to how documentation would appear, off to the side.

On its own, this plugin will do nothing. You must either use https://github.com/zbirenbaum/copilot-cmp to make the server into a cmp source, or write your own plugin to interface with it, via the request and handler methods located in copilot.utils.lua

## Install

### Preliminary Steps

Currently, you must have had the original copilot.vim installed and set up at some point, as the authentication steps you do during its setup create files in ~/.config/github-copilot which copilot.lua must read from to function. Fairly soon, copilot.lua will be able to perform this authentication step on its own, but as the plugin is in early stages, this has not yet been fully implemented.

Install copilot.vim with `use {"github/copilot.vim"}`, `:PackerSync`, restart, and run `:Copilot` to be prompted for the necessary setup steps.

After the setup steps are complete for copilot.vim, ensure that ~/.config/github-copilot has files in it, and then you are free to uninstall copilot.vim and proceed to the following steps.

### Setup

You have to run the `require("copilot").setup(options)` function in order to start Copilot. If no options are provided, the defaults are used.

Because the copilot server takes some time to start up, I HIGHLY recommend that you load copilot after startup. This can be done in multiple ways, the best one will depend on your existing config and the speed of your machine:

1. On 'VimEnter' + Defer: (My preferred method, works well with fast configs)
```
use{
  "zbirenbaum/copilot.lua",
  event = {"VimEnter"},
  config = function()
    vim.defer_fn(function()
      require("copilot").setup()
    end, 100)
  end,
}
```
2. Load After Statusline + defer: (If option (1) causes statusline to flicker, try this)
```
["zbirenbaum/copilot.lua"] = {
  "zbirenbaum/copilot.lua",
  after = 'feline.nvim', --whichever statusline plugin you use here
  config = function ()
    vim.defer_fn(function() require("copilot").setup() end, 100)
  end,
},
```
3. On 'InsertEnter': (The safest way to avoid statup lag. Note: Your copilot completions may take a moment to start showing up)

```
use {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  config = function ()
    vim.schedule(function() require("copilot").setup() end)
  end,
},
```


#### Configuration

The following is the default configuration:

```lua
{
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer", 
  server_opts_overrides = {},
  ft_disable = {}
}
```

##### plugin_manager_path

This is installation path of Packer, change this to the plugin manager installation path of your choice

Example:

```lua
require("copilot").setup {
  plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer", 
}
```

##### server_opts_overrides

Override copilot lsp client settings. See `:h vim.lsp.start_client` for list of options.

Example:

```lua
require("copilot").setup {
    server_opts_overrides = { trace = "verbose", name = "AI" },
}
```

##### ft_disable

Prevents copilot from attaching to buffers with specific filetypes.

Example:

```lua
require("copilot").setup {
    ft_disable = { "markdown", "terraform" },
}
```
