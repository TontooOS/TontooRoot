const { app, BrowserWindow, globalShortcut, ipcMain, screen } = require('electron');
const { execFile, spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

let installProcess = null;
const liveDesktopRequestPath = '/tmp/tontooos-try-live-desktop';

function clean(value) {
  if (value === null || value === undefined) {
    return '';
  }
  return String(value).trim();
}

function humanSize(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) {
    return 'Unknown size';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = value;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }

  const precision = size >= 10 || unitIndex === 0 ? 0 : 1;
  return `${size.toFixed(precision)} ${units[unitIndex]}`;
}

function childVolumes(children = []) {
  return children.flatMap((child) => {
    const label = clean(child.label);
    const name = clean(child.name).replace('/dev/', '');
    const fstype = clean(child.fstype);
    const mountpoint = clean(child.mountpoint);
    const size = humanSize(child.size);
    const title = label || name || 'Volume';
    const detail = [size, fstype, mountpoint].filter(Boolean).join(' / ');
    const current = child.type === 'part' ? [`${title}${detail ? ` (${detail})` : ''}`] : [];
    return current.concat(childVolumes(child.children || []));
  });
}

function normalizeDisk(device) {
  const pathName = clean(device.name);
  const basename = pathName.replace('/dev/', '');
  const vendor = clean(device.vendor);
  const model = clean(device.model);
  const displayName = [vendor, model].filter(Boolean).join(' ') || basename || 'Harddrive';
  const volumes = childVolumes(device.children || []);

  return {
    id: pathName || basename,
    path: pathName,
    name: displayName,
    size: humanSize(device.size),
    removable: clean(device.rm) === '1',
    readOnly: clean(device.ro) === '1',
    volumes
  };
}

function listHarddrives() {
  return new Promise((resolve, reject) => {
    execFile(
      '/usr/bin/lsblk',
      ['--json', '--bytes', '--paths', '--output', 'NAME,TYPE,SIZE,MODEL,VENDOR,LABEL,FSTYPE,MOUNTPOINT,RM,RO'],
      { timeout: 8000 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(stderr || error.message));
          return;
        }

        try {
          const parsed = JSON.parse(stdout);
          const devices = Array.isArray(parsed.blockdevices) ? parsed.blockdevices : [];
          resolve(devices.filter((device) => device.type === 'disk').map(normalizeDisk));
        } catch (parseError) {
          reject(parseError);
        }
      }
    );
  });
}

function normalizeInstallSettings(settings) {
  if (!settings || typeof settings !== 'object') {
    throw new Error('Installer settings are missing.');
  }

  const selectedHarddrive = clean(settings.selectedHarddrive);
  if (!selectedHarddrive.startsWith('/dev/')) {
    throw new Error('No harddrive was selected.');
  }

  const sshPort = Number(settings.sshPort || 22);

  return {
    selectedHarddrive,
    language: clean(settings.language) === 'de' ? 'de' : 'en',
    keyboard: clean(settings.keyboard) === 'de' ? 'de' : 'us',
    timezone: clean(settings.timezone) || 'Europe/Berlin',
    networkMode: clean(settings.networkMode) === 'wlan' ? 'wlan' : 'lan',
    wifiSsid: clean(settings.wifiSsid),
    username: clean(settings.username),
    firstName: clean(settings.firstName),
    lastName: clean(settings.lastName),
    computerName: clean(settings.computerName),
    password: String(settings.password || ''),
    theme: clean(settings.theme) === 'dark' ? 'dark' : 'light',
    themeColor: clean(settings.themeColor) || '#2563eb',
    avatar: clean(settings.avatar) || 'user',
    avatarColor: clean(settings.avatarColor) || '#2563eb',
    sshEnabled: Boolean(settings.sshEnabled),
    sshRootLogin: Boolean(settings.sshRootLogin),
    sshPort: Number.isInteger(sshPort) && sshPort >= 1 && sshPort <= 65535 ? sshPort : 22
  };
}

function sendInstallLine(sender, line, streamName) {
  const value = String(line || '').trimEnd();
  if (!value) {
    return;
  }

  const progressMatch = value.match(/^BASEOS_PROGRESS:(\d{1,3}):(.*)$/);
  if (progressMatch) {
    const percent = Math.max(0, Math.min(100, Number(progressMatch[1])));
    sender.send('install-progress', {
      percent,
      message: progressMatch[2].trim()
    });
    return;
  }

  sender.send('install-log', {
    line: value,
    stream: streamName
  });
}

function pipeInstallLines(stream, sender, streamName) {
  let buffered = '';

  stream.on('data', (chunk) => {
    buffered += chunk.toString('utf8');
    const lines = buffered.split(/\r?\n/);
    buffered = lines.pop() || '';
    lines.forEach((line) => sendInstallLine(sender, line, streamName));
  });

  stream.on('end', () => {
    sendInstallLine(sender, buffered, streamName);
    buffered = '';
  });
}

function startInstall(event, settings) {
  if (installProcess) {
    throw new Error('Installation is already running.');
  }

  const scriptPath = '/usr/local/lib/baseos-setup/install-system.sh';
  if (!fs.existsSync(scriptPath)) {
    throw new Error('Installer script is not available in this environment.');
  }

  const safeSettings = normalizeInstallSettings(settings);
  const isRoot = typeof process.getuid === 'function' && process.getuid() === 0;
  const command = isRoot ? scriptPath : '/usr/bin/sudo';
  const args = isRoot ? null : ['-n', scriptPath];

  if (!isRoot && !fs.existsSync(command)) {
    throw new Error('sudo is not available, so the installer cannot gain root privileges.');
  }

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'baseos-install-'));
  const settingsPath = path.join(tempDir, 'settings.json');
  fs.writeFileSync(settingsPath, JSON.stringify(safeSettings, null, 2), { mode: 0o600 });

  event.sender.send('install-log', {
    line: `Starting installer for ${safeSettings.selectedHarddrive} with root privileges`,
    stream: 'system'
  });

  installProcess = spawn(command, isRoot ? [settingsPath] : args.concat(settingsPath), {
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe']
  });

  pipeInstallLines(installProcess.stdout, event.sender, 'stdout');
  pipeInstallLines(installProcess.stderr, event.sender, 'stderr');

  installProcess.on('error', (error) => {
    event.sender.send('install-log', {
      line: error.message,
      stream: 'stderr'
    });
    event.sender.send('install-finished', {
      success: false,
      code: null,
      signal: null
    });
    installProcess = null;
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  installProcess.on('close', (code, signal) => {
    event.sender.send('install-finished', {
      success: code === 0,
      code,
      signal
    });
    installProcess = null;
    fs.rmSync(tempDir, { recursive: true, force: true });
  });

  return { started: true };
}

function tryLiveDesktop() {
  fs.writeFileSync(liveDesktopRequestPath, '1\n', { mode: 0o600 });
  app.quit();
  return { started: true };
}

function createWindow() {
  const appIcon = path.join(__dirname, 'assets', 'startup-settings.png');
  const displayBounds = screen.getPrimaryDisplay().bounds;
  const win = new BrowserWindow({
    x: displayBounds.x,
    y: displayBounds.y,
    width: displayBounds.width,
    height: displayBounds.height,
    backgroundColor: '#ececec',
    frame: false,
    fullscreen: true,
    fullscreenable: true,
    icon: appIcon,
    kiosk: true,
    movable: false,
    resizable: false,
    show: false,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  win.removeMenu();
  win.loadFile(path.join(__dirname, 'index.html'));

  win.once('ready-to-show', () => {
    win.setBounds(displayBounds);
    win.setFullScreen(true);
    win.setKiosk(true);
    win.show();
  });

  win.on('leave-full-screen', () => {
    win.setFullScreen(true);
  });
}

app.whenReady().then(() => {
  ipcMain.handle('list-harddrives', listHarddrives);
  ipcMain.handle('start-install', startInstall);
  ipcMain.handle('try-live-desktop', tryLiveDesktop);
  createWindow();
  globalShortcut.register('Control+Alt+D', () => {
    const win = BrowserWindow.getFocusedWindow();
    if (win) {
      win.webContents.toggleDevTools();
    }
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
