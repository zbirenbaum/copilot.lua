# Run all test files
test: deps/mini.nvim
	nvim --headless --noplugin -u ./tests/scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim
	nvim --headless --noplugin -u ./tests/scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

.PHONY: deps
deps: deps/mini.nvim

deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim deps/mini.nvim
	git clone https://github.com/jbyuki/one-small-step-for-vimkind deps/osv
