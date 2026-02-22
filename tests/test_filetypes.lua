local ft = require("copilot.client.filetypes")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_once = function() end,
    pre_case = function() end,
  },
})

T["filetypes()"] = MiniTest.new_set()

-- language_for_file_type tests

T["filetypes()"]["normalizes bash to shellscript"] = function()
  eq(ft.language_for_file_type("bash"), "shellscript")
end

T["filetypes()"]["normalizes cs to csharp"] = function()
  eq(ft.language_for_file_type("cs"), "csharp")
end

T["filetypes()"]["normalizes sh to shellscript"] = function()
  eq(ft.language_for_file_type("sh"), "shellscript")
end

T["filetypes()"]["normalizes text to plaintext"] = function()
  eq(ft.language_for_file_type("text"), "plaintext")
end

T["filetypes()"]["normalizes cuda to cuda-cpp"] = function()
  eq(ft.language_for_file_type("cuda"), "cuda-cpp")
end

T["filetypes()"]["normalizes dosbatch to bat"] = function()
  eq(ft.language_for_file_type("dosbatch"), "bat")
end

T["filetypes()"]["normalizes dosini to ini"] = function()
  eq(ft.language_for_file_type("dosini"), "ini")
end

T["filetypes()"]["normalizes make to makefile"] = function()
  eq(ft.language_for_file_type("make"), "makefile")
end

T["filetypes()"]["normalizes objc to objective-c"] = function()
  eq(ft.language_for_file_type("objc"), "objective-c")
end

T["filetypes()"]["normalizes objcpp to objective-cpp"] = function()
  eq(ft.language_for_file_type("objcpp"), "objective-cpp")
end

T["filetypes()"]["normalizes ps1 to powershell"] = function()
  eq(ft.language_for_file_type("ps1"), "powershell")
end

T["filetypes()"]["normalizes raku to perl6"] = function()
  eq(ft.language_for_file_type("raku"), "perl6")
end

T["filetypes()"]["normalizes bst to bibtex"] = function()
  eq(ft.language_for_file_type("bst"), "bibtex")
end

T["filetypes()"]["normalizes gitcommit to git-commit"] = function()
  eq(ft.language_for_file_type("gitcommit"), "git-commit")
end

T["filetypes()"]["normalizes gitrebase to git-rebase"] = function()
  eq(ft.language_for_file_type("gitrebase"), "git-rebase")
end

T["filetypes()"]["passes through unknown filetypes unchanged"] = function()
  eq(ft.language_for_file_type("python"), "python")
  eq(ft.language_for_file_type("lua"), "lua")
end

T["filetypes()"]["trims dot-separated filetypes"] = function()
  eq(ft.language_for_file_type("yaml.gotexttmpl"), "yaml")
  eq(ft.language_for_file_type("bash.zsh"), "shellscript")
end

T["filetypes()"]["empty filetype returns plaintext"] = function()
  eq(ft.language_for_file_type(""), "plaintext")
end

-- is_ft_disabled tests

T["filetypes()"]["is_ft_disabled exact match enabled"] = function()
  local disabled, _ = ft.is_ft_disabled("python", { python = true })
  eq(disabled, false)
end

T["filetypes()"]["is_ft_disabled exact match disabled"] = function()
  local disabled, _ = ft.is_ft_disabled("python", { python = false })
  eq(disabled, true)
end

T["filetypes()"]["is_ft_disabled short filetype match"] = function()
  local disabled, _ = ft.is_ft_disabled("yaml.gotexttmpl", { yaml = false })
  eq(disabled, true)
end

T["filetypes()"]["is_ft_disabled wildcard enabled"] = function()
  local disabled, _ = ft.is_ft_disabled("python", { ["*"] = true })
  eq(disabled, false)
end

T["filetypes()"]["is_ft_disabled wildcard disabled"] = function()
  local disabled, _ = ft.is_ft_disabled("python", { ["*"] = false })
  eq(disabled, true)
end

T["filetypes()"]["is_ft_disabled falls through to internal_filetypes"] = function()
  local disabled, reason = ft.is_ft_disabled("yaml", {})
  eq(disabled, true)
  eq(type(reason), "string")
end

T["filetypes()"]["is_ft_disabled internal filetypes help disabled"] = function()
  local disabled, _ = ft.is_ft_disabled("help", {})
  eq(disabled, true)
end

T["filetypes()"]["is_ft_disabled internal filetypes gitcommit disabled"] = function()
  local disabled, _ = ft.is_ft_disabled("gitcommit", {})
  eq(disabled, true)
end

T["filetypes()"]["is_ft_disabled internal filetypes overridden by user config"] = function()
  local disabled, _ = ft.is_ft_disabled("markdown", { markdown = true })
  eq(disabled, false)
end

T["filetypes()"]["is_ft_disabled unknown filetype not disabled"] = function()
  local disabled, reason = ft.is_ft_disabled("python", {})
  eq(disabled, false)
  eq(reason, nil)
end

T["filetypes()"]["is_ft_disabled callable value"] = function()
  local disabled, _ = ft.is_ft_disabled("python", {
    python = function()
      return true
    end,
  })
  eq(disabled, false)

  local disabled2, _ = ft.is_ft_disabled("python", {
    python = function()
      return false
    end,
  })
  eq(disabled2, true)
end

T["filetypes()"]["is_ft_disabled exact match takes priority over wildcard"] = function()
  local disabled, _ = ft.is_ft_disabled("python", { python = true, ["*"] = false })
  eq(disabled, false)
end

T["filetypes()"]["is_ft_disabled internal filetype dot separator"] = function()
  local disabled, _ = ft.is_ft_disabled("markdown.pandoc", {})
  eq(disabled, true)
end

return T
