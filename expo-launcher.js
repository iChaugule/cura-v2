const path = require('path');
const { spawn } = require('child_process');

const expoDir = path.join(__dirname, 'expo-app');
const expoCli = path.join(expoDir, 'node_modules', 'expo', 'bin', 'cli');
const port = process.env.PORT || '8081';

const child = spawn(process.execPath, [expoCli, 'start', '--port', port], {
  cwd: expoDir,
  stdio: 'inherit',
  env: { ...process.env },
});

child.on('exit', (code) => process.exit(code || 0));
