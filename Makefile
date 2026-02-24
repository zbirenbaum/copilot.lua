# Run formatting and linting checks (matches CI)
lint:
	stylua --check lua/ --config-path=.stylua.toml
	luacheck lua/ --globals vim

# Auto-fix formatting
fmt:
	stylua lua/ --config-path=.stylua.toml

# Run all test files
# test: deps/mini.nvim
test:
	nvim --headless --noplugin -u ./tests/scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim
	nvim --headless --noplugin -u ./tests/scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Download 'mini.nvim' to use its 'mini.test' testing module
# deps/mini.nvim:
# 	@mkdir deps
# 	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim deps/mini.nvim 
# 	git clone https://github.com/jbyuki/one-small-step-for-vimkind deps/osv
