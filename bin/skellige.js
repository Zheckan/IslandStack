#!/usr/bin/env node

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
// swift run --quiet hides build progress, so say why the first run is slow.
if (!fs.existsSync(path.join(root, '.build', 'debug', 'skellige'))) {
  console.error('skellige: building the CLI with Swift (first run only)...');
}
const result = spawnSync('swift', ['run', '--quiet', 'skellige', ...process.argv.slice(2)], {
  cwd: root,
  stdio: 'inherit',
});

if (result.error) {
  console.error(`skellige: ${result.error.message}`);
  process.exit(1);
}
if (result.signal) process.kill(process.pid, result.signal);
process.exit(result.status);
