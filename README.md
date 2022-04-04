# copilot.lua

This plugin is the pure lua replacement for https://github.com/github/copilot.vim

While using copilot.vim, for the first time since I started using neovim my laptop began to overheat. Additionally, I found the large chunks of ghost text moving around my code, and interfering with my existing cmp ghost text disturbing. As lua is far more efficient and make things easier to integrate with modern plugins, this repository was created. 

## (IMPORTANT) Usage:
Note that this plugin will only start up the copilot server. The current usage of this is via https://github.com/zbirenbaum/copilot-cmp, which turns copilot suggestions into menu entries for cmp, and displays the full text body in a float, similar to how documentation would appear, off to the side.

On its own, this plugin will do nothing. You must either use https://github.com/zbirenbaum/copilot-cmp to make the server into a cmp source, or write your own plugin to interface with it, via the request and handler methods located in copilot.utils.lua

## Install

### Preliminary Steps
Currently, you must have had the original copilot.vim installed and set up at some point, as the authentication steps you do during its setup create files in ~/.config/github-copilot which copilot.lua must read from to function. Fairly soon, copilot.lua will be able to perform this authentication step on its own, but as the plugin is in early stages, this has not yet been fully implemented.

Install copilot.vim with `use {"github/copilot.vim"}`, `:PackerSync`, restart, and run `:Copilot` to be prompted for the necessary setup steps. 

After the setup steps are complete for copilot.vim, ensure that ~/.config/github-copilot has files in it, and then you are free to uninstall copilot.vim and proceed to the following steps.

### Setup
Because the copilot server takes some time to start up, I HIGHLY recommend that you load copilot after startup. This can be done in multiple ways:
1. On 'InsertEnter': (My preferred way)
```
use {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  config = function ()
    vim.schedule(function() require("copilot") end)
  end,
},
```
2. Load After Statusline + defer:
```
["zbirenbaum/copilot.lua"] = {
  "zbirenbaum/copilot.lua",
  after = 'feline.nvim', --whichever statusline plugin you use here
  config = function ()
    vim.defer_fn(function() require("copilot") end, 100)
  end,
},
```


