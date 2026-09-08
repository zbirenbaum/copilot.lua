#!/usr/bin/env node
// CI-only adapter for the pinned public API; never used by the Neovim plugin.
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {GitHub, Manifest, VERSION} = require('release-please');

const CONFIG = 'release-please-config.json';
const VERSIONS = '.release-please-manifest.json';
const STABLE = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

async function generate(github, cwd = process.cwd()) {
  assert.equal(VERSION, '17.6.0', 'Re-review boundary guards before changing release-please');
  const git = (...args) => execFileSync('git', args, {cwd, encoding: 'utf8'}).trim();
  const localVersions = JSON.parse(git('show', `HEAD:${VERSIONS}`));
  assert.deepEqual(Object.keys(localVersions), ['.'], 'Only a single root boundary is supported');
  const version = localVersions['.'];
  assert.ok(typeof version === 'string' && STABLE.test(version), 'Invalid local boundary version');
  const sha = git('rev-parse', '--verify', `refs/tags/v${version}^{commit}`);
  git('merge-base', '--is-ancestor', sha, 'HEAD');

  // Deliberately narrow: new strategies, custom tags, bootstrap overrides, or
  // plugins require reviewing these guards, not silently changing their meaning.
  const config = JSON.parse(git('show', `HEAD:${CONFIG}`));
  assert.deepEqual(Object.keys(config), ['packages'], 'Unsupported release config');
  assert.deepEqual(Object.keys(config.packages), ['.'], 'Unsupported release config roots');
  const root = config.packages['.'];
  assert.equal(root['release-type'], 'simple', 'Unsupported release config strategy');
  assert.equal(root['include-component-in-tag'], false, 'Unsupported release config tags');
  assert.ok(Object.keys(root).every(key => ['release-type', 'include-component-in-tag', 'changelog-sections'].includes(key)), 'Unsupported release config options');

  // Validate the config observation actually consumed by fromManifest. Do not
  // preflight one API read and then let the constructor silently fetch another.
  const getFileJson = github.getFileJson;
  github.getFileJson = async function (file, ...args) {
    const json = await getFileJson.call(this, file, ...args);
    if (file === CONFIG) assert.deepEqual(json, config, 'Remote release config differs from verified checkout');
    return json;
  };
  let manifest;
  try {
    manifest = await Manifest.fromManifest(github, 'master');
  } finally {
    github.getFileJson = getFileJson;
  }
  assert.deepEqual(Object.keys(manifest.releasedVersions), ['.'], 'Only a single root boundary is supported');
  assert.equal(manifest.releasedVersions['.'].toString(), version, 'Loaded version differs from verified boundary');

  // Capture one real observation. The fallback inside Manifest must see this
  // same verified tag, even if a subsequent GitHub listing would be stale.
  const tags = [];
  for await (const tag of github.tagIterator()) tags.push({...tag});
  const boundaryTags = tags.filter(tag => tag.name === `v${version}`);
  assert.ok(boundaryTags.length > 0 && boundaryTags.every(tag => tag.sha === sha), 'Tag observation does not match verified boundary');
  github.tagIterator = async function* () {
    for (const tag of tags) yield {...tag};
  };

  // Release Please prefers release objects to tags. Both vX.Y.Z and X.Y.Z are
  // root names accepted upstream. Reject noncanonical names rather than letting
  // upstream's permissive parsing normalize an unchecked name into our version.
  const releaseIterator = github.releaseIterator;
  github.releaseIterator = async function* (...args) {
    for await (const release of releaseIterator.apply(this, args)) {
      assert.ok(typeof release.tagName === 'string', 'Invalid release observation');
      const releaseVersion = release.tagName.replace(/^v/, '');
      assert.ok(STABLE.test(releaseVersion), 'Unsupported release tag name');
      if (releaseVersion === version) assert.equal(release.sha, sha, 'Release observation does not match verified boundary');
      yield release;
    }
  };

  // Preserve upstream commit/PR metadata and history traversal. Merely warning
  // at the 500-commit limit would allow a partial or bootstrapped release.
  const mergeCommitIterator = github.mergeCommitIterator;
  github.mergeCommitIterator = async function* (...args) {
    let found = false;
    for await (const commit of mergeCommitIterator.apply(this, args)) {
      if (commit.sha === sha) found = true;
      yield commit;
    }
    assert.ok(found, 'History exhausted without verified boundary');
  };
  return manifest.createPullRequests(); // The SAME instance; no release creation.
}

if (require.main === module) {
  (async () => {
    const {GH_TOKEN, GITHUB_REPOSITORY} = process.env;
    assert.ok(GH_TOKEN, 'GH_TOKEN is required');
    assert.equal(GITHUB_REPOSITORY, 'zbirenbaum/copilot.lua', 'Only the upstream repository is supported');
    const [owner, repo] = GITHUB_REPOSITORY.split('/');
    const github = await GitHub.create({owner, repo, token: GH_TOKEN});
    await generate(github);
  })().catch(error => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {generate};
