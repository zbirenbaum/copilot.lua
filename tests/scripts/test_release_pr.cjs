const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {Manifest, VERSION, setLogger} = require('release-please');

assert.equal(VERSION, '17.6.0');
setLogger({debug() {}, info() {}, warn() {}, error() {}});
const config = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../release-please-config.json')));
const generate = (...args) => require('../../.github/scripts/release-pr.cjs').generate(...args);

function fixture(t, options = {}) {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'release-pr-'));
  t.after(() => fs.rmSync(cwd, {recursive: true, force: true}));
  const git = (...args) => execFileSync('git', args, {cwd, encoding: 'utf8', env: {
    ...process.env, GIT_AUTHOR_NAME: 'Test', GIT_AUTHOR_EMAIL: 'test@example.com',
    GIT_COMMITTER_NAME: 'Test', GIT_COMMITTER_EMAIL: 'test@example.com',
  }}).trim();
  git('init', '-q', '--initial-branch=master');
  fs.writeFileSync(path.join(cwd, '.release-please-manifest.json'), JSON.stringify({'.': '3.0.3'}));
  fs.writeFileSync(path.join(cwd, 'release-please-config.json'), JSON.stringify(options.localConfig || config));
  git('add', '.');
  git('commit', '-qm', 'chore: boundary');
  const sha = git('rev-parse', 'HEAD');
  git('tag', '-a', 'v3.0.3', '-m', 'published boundary'); // Must peel annotated tag.
  const commit = (message, id) => ({sha: id.repeat(40), message, files: ['lua/copilot/init.lua']});
  const state = {
    version: options.version || '3.0.3', reads: 0, tagReads: 0, writes: [], seen: [],
    commits: [commit(options.message || 'fix: current fix', 'a'),
      {sha, message: 'chore: boundary', files: ['.release-please-manifest.json']},
      commit('feat!: historical breaking change', 'b')],
  };
  const github = {
    repository: {owner: 'zbirenbaum', repo: 'copilot.lua', defaultBranch: 'master'},
    async getFileJson(file, ref) {
      assert.equal(ref, 'master');
      if (options.apiError) throw new Error('SCM unavailable');
      if (file === 'release-please-config.json') return structuredClone(options.remoteConfig || config);
      assert.equal(file, '.release-please-manifest.json');
      state.reads++;
      return options.versions || {'.': state.version};
    },
    async *tagIterator() {
      state.tagReads++;
      // This runs after construction: a second Manifest would load an unchecked version.
      if (options.advanceAfterConstruction) state.version = '3.0.4';
      if (options.tagError) throw new Error('tag API unavailable');
      if (state.tagReads > 1 || options.missingTag) return;
      yield {name: 'v3.0.3', sha: options.tagSha || sha};
    },
    async *releaseIterator() {
      if (options.releaseError) throw new Error('release API unavailable');
      for (const release of options.releases || []) yield {...release, sha: release.sha === 'boundary' ? sha : release.sha};
    },
    async *mergeCommitIterator(ref, opts) {
      assert.equal(ref, 'master');
      assert.equal(opts.backfillFiles, true);
      for (const c of state.commits.slice(0, opts.maxResults)) {
        state.seen.push(c.sha);
        yield c;
      }
    },
    async *pullRequestIterator() {},
    async createPullRequest(pr, branch, message, updates) {
      assert.equal(branch, 'master');
      const update = updates.find(u => u.path === '.release-please-manifest.json');
      const version = JSON.parse(update.updater.updateContent(JSON.stringify({'.': state.version})))['.'];
      state.writes.push({pr, version});
      return {...pr, number: 1};
    },
    async createRelease() { assert.fail('Generation must never create releases'); },
  };
  return {cwd, github, state, sha, git};
}

test('reproduces old unguarded reload bootstrapping across historical breaking commits', async t => {
  const f = fixture(t, {version: '3.0.4'});
  await (await Manifest.fromManifest(f.github, 'master')).createPullRequests();
  assert.equal(f.state.writes[0].version, '4.0.0');
  assert.ok(f.state.seen.includes('b'.repeat(40)));
});

for (const [message, expected] of [['fix: current fix', '3.0.4'], ['feat: new feature', '3.1.0'], ['feat!: genuine break', '4.0.0']]) {
  test(`real Manifest preserves ${expected} versioning and excludes old breaking history`, async t => {
    const f = fixture(t, {message, advanceAfterConstruction: true});
    await generate(f.github, f.cwd);
    assert.equal(f.state.writes.length, 1);
    assert.equal(f.state.writes[0].version, expected);
    assert.ok(!f.state.writes[0].pr.body.includes('historical breaking change'));
    assert.ok(!f.state.seen.includes('b'.repeat(40)));
    assert.equal(f.state.reads, 1, 'The validated Manifest must not be reconstructed');
    assert.equal(f.state.tagReads, 1, 'Reuse captured tags instead of stale live listing');
    assert.equal(f.state.version, '3.0.4', 'Remote advanced after construction');
  });
}

test('no commits after boundary produces no PR', async t => {
  const f = fixture(t);
  f.state.commits.shift();
  assert.deepEqual(await generate(f.github, f.cwd), []);
  assert.equal(f.state.writes.length, 0);
});

for (const [name, options, error] of [
  ['master advances after outer guard', {version: '3.0.4'}, /version.*boundary/i],
  ['extra manifest root', {versions: {'.': '3.0.3', other: '1.0.0'}}, /root/i],
  ['manifest API error', {apiError: true}, /SCM unavailable/],
  ['missing tag', {missingTag: true}, /tag.*boundary/i],
  ['wrong tag SHA', {tagSha: 'c'.repeat(40)}, /tag.*boundary/i],
  ['tag API error', {tagError: true}, /tag API unavailable/],
  ['release API error', {releaseError: true}, /release API unavailable/],
  ['changed remote config', {remoteConfig: {packages: {'.': {'release-type': 'node'}}}}, /config/i],
  ['custom local and remote tag semantics', {localConfig: {packages: {'.': {'release-type': 'simple', 'include-component-in-tag': false, 'include-v-in-tag': false}}}, remoteConfig: {packages: {'.': {'release-type': 'simple', 'include-component-in-tag': false, 'include-v-in-tag': false}}}}, /config/i],
  ...['v3.0.3', '3.0.3'].map(tagName => [`release-first wrong SHA ${tagName}`, {releases: [{tagName, sha: 'd'.repeat(40)}]}, /release.*boundary/i]),
]) {
  test(`${name} fails before any writes`, async t => {
    const f = fixture(t, options);
    await assert.rejects(generate(f.github, f.cwd), error);
    assert.equal(f.state.writes.length, 0);
  });
}

for (const tagName of ['v3.0.3', '3.0.3']) {
  test(`matching release-first observation ${tagName} preserves the verified boundary`, async t => {
    const f = fixture(t, {releases: [{tagName, sha: 'boundary', notes: 'published'}]});
    await generate(f.github, f.cwd);
    assert.equal(f.state.writes[0].version, '3.0.4');
    assert.ok(!f.state.seen.includes('b'.repeat(40)));
  });
}

for (const truncated of [false, true]) {
  test(`${truncated ? '500-depth truncated' : 'missing'} history boundary fails before writes`, async t => {
    const f = fixture(t);
    if (truncated) {
      f.state.commits.unshift(...Array.from({length: 500}, (_, i) => ({sha: `${i}`.padStart(40, 'e'), message: 'fix: recent', files: []})));
    } else {
      f.state.commits.splice(1, 1);
    }
    await assert.rejects(generate(f.github, f.cwd), /history.*boundary/i);
    assert.equal(f.state.writes.length, 0);
  });
}
