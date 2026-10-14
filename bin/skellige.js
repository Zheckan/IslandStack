#!/usr/bin/env node

const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const result = spawnSync('swift', ['run', 'skellige', ...process.argv.slice(2)], {
  cwd: root,
  stdio: 'inherit',
});

if (result.error) {
  console.error(`skellige: ${result.error.message}`);
  process.exit(1);
}
if (result.signal) process.kill(process.pid, result.signal);
process.exit(result.status);
