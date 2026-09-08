#!/usr/bin/env ruby
require 'yaml'
require 'open3'
require 'tmpdir'

ROOT = File.expand_path('../..', __dir__)
def workflow(name)
  YAML.load_file(File.join(ROOT, '.github/workflows', name))
end
def check(value, message)
  raise message unless value
end
def step(job, id)
  job.fetch('steps').find { |s| s['id'] == id } or raise "Missing step #{id}"
end
def events(w)
  w.fetch('on') { w.fetch(true) } # Psych YAML 1.1 treats unquoted on as true.
end

r = workflow('release.yml')
u = workflow('update-copilot-nodejs.yaml')
l = workflow('lint.yml')
check(r['permissions'] == { 'contents' => 'read', 'pull-requests' => 'read' }, 'Release must default to read-only permissions')
check(events(r).keys.sort == %w[pull_request push workflow_dispatch], 'Release event ownership')
check(events(r).dig('push', 'branches') == ['master'], 'Push must target master')
check(events(r).dig('pull_request', 'branches') == ['master'], 'PR validation must target master')
check(events(r).dig('pull_request', 'types') == %w[opened synchronize reopened], 'Validate updated heads, not closed PRs')
writer = r.fetch('jobs').fetch('release')
check(writer['if'] == "github.repository == 'zbirenbaum/copilot.lua' && github.ref == 'refs/heads/master' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch')", 'Writer must be upstream master push/manual only')
check(writer['permissions'] == { 'contents' => 'write', 'pull-requests' => 'write' }, 'Writer permissions')
check(writer['concurrency'] == { 'group' => 'release-${{ github.repository }}-${{ github.ref }}', 'cancel-in-progress' => false }, 'Serialize branch writers without cancelling')
check(!r.key?('concurrency'), 'PR checks must not share writer concurrency')
steps = writer.fetch('steps')
check(steps.map { |s| s['id'] } == %w[publish checkout node release_deps tags reconcile current generate], 'Publish -> checkout/setup -> tags -> reconcile -> guard -> generate ordering')
check(step(writer, 'publish')['uses'] == 'googleapis/release-please-action@v5', 'Publication action')
check(step(writer, 'publish')['with'] == { 'target-branch' => 'master', 'skip-github-pull-request' => true }, 'Publish only, never calculate first')
check(step(writer, 'generate')['run'] == 'node .github/scripts/release-pr.cjs', 'Generate through checked public API entrypoint, not a refetching action')
check(!step(writer, 'generate').key?('uses'), 'Only publication uses Release Please action')
steps.each { |s| check(!s.key?('if') && !s['continue-on-error'], 'Writer must stop on any failure') }
check(step(writer, 'checkout').dig('with', 'ref') == 'master', 'Checkout latest master, not event SHA')
check(step(writer, 'checkout').dig('with', 'fetch-depth') == 0, 'Writer needs full history')
check(step(writer, 'tags')['run'].lines.map(&:strip).include?('git fetch origin --tags'), 'Refresh current tags')
check(step(writer, 'reconcile')['run'].lines.map(&:strip).include?('bash .github/scripts/lsp-release.sh reconcile'), 'Use verified reconciliation')
credentials = { 'GH_TOKEN' => '${{ github.token }}', 'GITHUB_REPOSITORY' => '${{ github.repository }}' }
check(step(writer, 'reconcile')['env'] == credentials, 'Reconcile credentials and repository')
check(step(writer, 'generate')['env'] == credentials, 'Generation credentials and repository')

pr = r.fetch('jobs').fetch('validate_lsp_pr')
check(pr['name'] == 'Validate LSP release PR', 'Stable required check name')
check(pr['if'] == "github.event_name == 'pull_request' && github.repository == 'zbirenbaum/copilot.lua' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.head.ref == 'create-pull-request/update-copilot-lsp'", 'Only trusted updater PRs may validate')
check(!pr.key?('permissions') || pr['permissions'] == r['permissions'], 'Validator must be read-only')
check(pr['steps'].map { |s| s['id'] } == %w[checkout validate], 'Never checkout PR-controlled helper')
check(step(pr, 'checkout')['with'] == { 'ref' => 'master', 'fetch-depth' => 0, 'persist-credentials' => false }, 'Trusted current base checkout, full history, no persisted token')
validate = step(pr, 'validate')
check(validate['env'] == credentials.merge('PR_HEAD_SHA' => '${{ github.event.pull_request.head.sha }}'), 'Pass head SHA through environment')
check(!validate['run'].include?('${{'), 'No expression interpolation into shell')
check(r['jobs'].keys.sort == %w[release validate_lsp_pr], 'Only one writer job')

# Execute actual workflow snippets with narrow command fixtures, not an Actions
# emulator. A changed or unreachable master must fail the writer guard.
git_fixture = <<~'SH'
  git() {
    case "$*" in
      'rev-parse HEAD') printf '%s\n' snapshot ;;
      'ls-remote --exit-code origin refs/heads/master')
        [ "$REMOTE" != error ] || return 1
        printf '%s\trefs/heads/master\n' "$REMOTE" ;;
      *) return 99 ;;
    esac
  }
SH
%w[snapshot advanced error].each do |remote|
  out, status = Open3.capture2e({ 'REMOTE' => remote }, 'bash', '-e', '-c', git_fixture + step(writer, 'current')['run'])
  check(status.success? == (remote == 'snapshot'), "Master guard failed for #{remote}: #{out}")
end

# Check fetch order and safe arguments. Fetching the PR object must not replace
# the trusted checkout. Either fetch failing must prevent the helper invocation.
Dir.mktmpdir('release-workflow') do |dir|
  fixture = <<~'SH'
    git() {
      printf 'git'; printf ' <%s>' "$@"; printf '\n'
      [ "$*" != "$FAIL_FETCH" ]
    }
    bash() {
      printf 'helper'; printf ' <%s>' "$@"; printf '\n'
    }
  SH
  sha = '$(touch INJECTED); head with spaces'
  out, status = Open3.capture2e({ 'PR_HEAD_SHA' => sha, 'FAIL_FETCH' => '' }, 'bash', '-e', '-c', fixture + validate['run'], chdir: dir)
  check(status.success?, out)
  check(out.lines.map(&:strip) == [
    'git <fetch> <origin> <--tags> <+refs/heads/master:refs/remotes/origin/master>',
    "git <fetch> <origin> <#{sha}>",
    "helper <.github/scripts/lsp-release.sh> <check-pr> <origin/master> <#{sha}>"
  ], "Fetch current base, separately fetch head, then check safely: #{out}")
  check(!File.exist?(File.join(dir, 'INJECTED')), 'PR input executed as shell')
  ['fetch origin --tags +refs/heads/master:refs/remotes/origin/master', "fetch origin #{sha}"].each do |failure|
    out, status = Open3.capture2e({ 'PR_HEAD_SHA' => sha, 'FAIL_FETCH' => failure }, 'bash', '-e', '-c', fixture + validate['run'], chdir: dir)
    check(!status.success? && !out.include?('helper'), 'Fetch failure must block validation')
  end
end

check(!events(u).key?('pull_request'), 'Updater no longer owns closed PR events')
check(u['jobs'].keys == ['update_copilot_lsp'], 'Remove separate tag writer')
check(u['permissions'] == { 'contents' => 'read' }, 'Updater defaults read-only')
up = u['jobs'].fetch('update_copilot_lsp')
check(up['steps'].none? { |s| s['run'].to_s.match?(/lsp-release\.sh (tag|reconcile)/) }, 'Updater must not publish tags')
[up, l['jobs'].fetch('release_automation')].each do |job|
  check(job['steps'].any? { |s| s['run'].to_s.lines.map(&:strip).include?('ruby tests/scripts/test_release_workflow.rb') }, 'Run parsed contracts in updater and Lint CI')
  check(job['steps'].any? { |s| s['run'].to_s.lines.map(&:strip).include?('node --test tests/scripts/test_release_pr.cjs') }, 'Run real Manifest tests in updater and Lint CI')
end
[writer, up, l['jobs'].fetch('release_automation')].each do |job|
  check(step(job, 'node')['uses'] == 'actions/setup-node@v6' && step(job, 'node').dig('with', 'node-version') == 22, 'Explicit Node test/tool runtime')
  install = step(job, 'release_deps')['run']
  check(install.lines.map(&:strip).include?('npm install --prefix "$RUNNER_TEMP/release-please" --no-save --package-lock=false --ignore-scripts release-please@17.6.0'), 'Pin public API dependency, disable scripts, install outside repository')
  check(install.lines.map(&:strip).include?('echo "NODE_PATH=$RUNNER_TEMP/release-please/node_modules" >> "$GITHUB_ENV"'), 'Expose temporary dependency to following steps')
  ids = job['steps'].map { |s| s['id'] }
  check(ids.index('node') < ids.index('release_deps'), 'Set up Node before installing')
  consumer = job['steps'].index { |s| s['run'].to_s.include?('node --test') || s['run'] == 'node .github/scripts/release-pr.cjs' }
  check(ids.index('release_deps') < consumer, 'Install before testing/generation')
end
puts 'Release workflow tests passed'
