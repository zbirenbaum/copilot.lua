# copilot.lua

This plugin is the pure lua replacement for https://github.com/github/copilot.vim

While using copilot.vim, for the first time since I started using neovim my laptop began to overheat. Additionally, I found the large chunks of ghost text moving around my code, and interfering with my existing cmp ghost text disturbing. As lua is far more efficient and makes things easier to integrate with modern plugins, this repository was created.

## (IMPORTANT) Usage:

Note that this plugin will only start up the copilot server. The current usage of this is via https://github.com/zbirenbaum/copilot-cmp, which turns copilot suggestions into menu entries for cmp, and displays the full text body in a float, similar to how documentation would appear, off to the side.

On its own, this plugin will do nothing. You must either use https://github.com/zbirenbaum/copilot-cmp to make the server into a cmp source, or write your own plugin to interface with it, via the request and handler methods located in copilot.utils.lua

## Install

### Authentication

Once copilot is started, run `:CopilotAuth` to start the authentication process.

### Setup

You have to run the `require("copilot").setup(options)` function in order to start Copilot. If no options are provided, the defaults are used.

Because the copilot server takes some time to start up, I HIGHLY recommend that you load copilot after startup. This can be done in multiple ways, the best one will depend on your existing config and the speed of your machine:

1. On 'VimEnter' + Defer: (My preferred method, works well with fast configs)
```lua
use {
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
```lua
use {
  "zbirenbaum/copilot.lua",
  after = 'feline.nvim', --whichever statusline plugin you use here
  config = function ()
    vim.defer_fn(function() require("copilot").setup() end, 100)
  end,
}
```
3. On 'InsertEnter': (The safest way to avoid statup lag. Note: Your copilot completions may take a moment to start showing up)

```lua
use {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  config = function ()
    vim.schedule(function() require("copilot").setup() end)
  end,
}
```


#### Configuration

The following is the default configuration:

```lua
panel = { -- no config options yet
  enabled = true,
},
suggestion = {
  enabled = true,
  auto_trigger = false,
  debounce = 75,
  keymap = {
   accept = "<M-l>",
   next = "<M-]>",
   prev = "<M-[>",
   dismiss = "<C-]>",
  },
},
filetypes = {
  yaml = false,
  markdown = false,
  help = false,
  gitcommit = false,
  gitrebase = false,
  hgcommit = false,
  svn = false,
  cvs = false,
  ["."] = false,
},
copilot_node_command = 'node', -- Node version must be < 18
plugin_manager_path = vim.fn.stdpath("data") .. "/site/pack/packer",
server_opts_overrides = {},
```

##### panel

Enabling panel creates the `CopilotPanel` command, which allows you to preview completions in a split window. Navigating to the split window allows you to jump between them and see each one. (<CR> to accept completion not yet implemented, coming soon)

```lua
require("copilot").setup {
  panel = {
    enabled = false,
  }
},

```

##### suggestion

When `auto_trigger` is `true`, copilot starts suggesting as soon as you enter insert mode. 

When `auto_trigger` is `false`, use the `next` or `prev` keymap to trigger copilot suggestion.

To toggle auto trigger for the current buffer, use `require("copilot.suggestion").toggle_auto_trigger()`.

Copilot suggestion is automatically hidden when `popupmenu-completion` is open. In case you use a custom
menu for completion, you can set the `copilot_suggestion_hidden` buffer variable to `true` to have the
same behavior. For example, with `nvim-cmp`:

```lua
cmp.event:on("menu_opened", function()
  vim.b.copilot_suggestion_hidden = true
end)

cmp.event:on("menu_closed", function()
  vim.b.copilot_suggestion_hidden = false
end)
```


##### filetypes

Specify filetypes for attaching copilot.

Example:

```lua
require("copilot").setup {
  filetypes = {
    markdown = true, -- overrides default
    terraform = false, -- disallow specific filetype
  },
}
```

If you add `"*"` as a filetype, the default configuration for `filetypes` won't be used anymore. e.g.

```lua
require("copilot").setup {
  filetypes = {
    javascript = true, -- allow specific filetype
    typescript = true, -- allow specific filetype
    ["*"] = false, -- disable for all other filetypes and ignore default `filetypes`
  },
}
```

##### copilot_node_command

Use this field to provide the path to a specific node version such as one installed by nvm. Node version must be < 18. The LTS version of node (16.17.0) is recommended.

Example:

```lua
copilot_node_command = vim.fn.expand("$HOME") .. "/.config/nvm/versions/node/v16.14.2/bin/node", -- Node version must be < 18
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

Override copilot lsp client settings. The `settings` field is where you can set the values of the options defined in SettingsOpts.md. These options are specific to the copilot lsp and can be used to customize its behavior. Ensure that the name field is not overriden as is is used for efficiency reasons in numerous checks to verify copilot is actually running. See `:h vim.lsp.start_client` for list of options.

Example:

```lua
require("copilot").setup {
  server_opts_overrides = {
    trace = "verbose",
    settings = {
      advanced = {
        listCount = 10, -- #completions for panel
        inlineSuggestCount = 3, -- #completions for getCompletions
      }
    },
  }
},
```
