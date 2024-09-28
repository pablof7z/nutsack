import fs from 'fs/promises';
import path from 'path';
import os from 'os';

function getNutsackPath(): string {
  const homeDir = os.homedir();
  return path.join(homeDir, '.nutsack');
}

export async function readNsecFromFile(): Promise<string | null> {
  try {
    const nsecPath = getNutsackPath();
    const nsec = await fs.readFile(nsecPath, 'utf-8');
    return nsec.trim();
  } catch (error) {
    return null;
  }
}

export async function handleNsecCommand(nsec: string): Promise<void> {
  try {
    const filePath = getNutsackPath();
    await fs.writeFile(filePath, nsec, 'utf-8');
    console.log(`NSEC successfully written to ${filePath}`);
  } catch (error) {
    console.error('Error writing NSEC:', error);
  }
}
