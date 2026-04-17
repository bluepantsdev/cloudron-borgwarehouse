import fs from 'fs';
import path from 'path';

export default function getConfigDirectory() {
  const candidates = [
    process.env.CONFIG_PATH,
    '/app/data/config',
    path.join(process.cwd(), '/config'),
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      fs.mkdirSync(candidate, { recursive: true });
      fs.accessSync(candidate, fs.constants.R_OK | fs.constants.W_OK);
      return candidate;
    } catch (error) {
      // Try next candidate path
    }
  }

  throw new Error('No writable config directory found');
}