const { app, BrowserWindow, ipcMain, screen } = require('electron');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const DOCK_WIDTH = 165;
const DOCK_HEIGHT = 78;
const DOCK_MARGIN = 14;
const LOG_FILE = path.join(process.env.XDG_CACHE_HOME || path.join(process.env.HOME || '/tmp', '.cache'), 'tontooos', 'tontoo-dock.log');

let dockWindow;

app.setName('Tontoo Dock');
app.setPath('userData', '/tmp/tontoo-dock');
app.commandLine.appendSwitch('class', 'tontoo-dock');
app.commandLine.appendSwitch('disable-pinch');
app.commandLine.appendSwitch('enable-transparent-visuals');
app.commandLine.appendSwitch('enable-features', 'UseOzonePlatform');
app.commandLine.appendSwitch('ozone-platform', 'x11');
app.commandLine.appendSwitch('ozone-platform-hint', 'x11');

function formatLogValue(value) {
  if (value instanceof Error) {
    return value.stack || value.message;
  }

  if (typeof value === 'object') {
    try {
      return JSON.stringify(value);
    } catch (_error) {
      return String(value);
    }
  }

  return String(value);
}

function logDock(message, detail) {
  const suffix = detail === undefined ? '' : ` ${formatLogValue(detail)}`;
  const line = `[${new Date().toISOString()}] ${message}${suffix}\n`;

  try {
    fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
    fs.appendFileSync(LOG_FILE, line);
  } catch (_error) {
    process.stderr.write(line);
  }
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(__dirname, relativePath), 'utf8'));
}

function detectLocale() {
  const rawLocale = process.env.LC_ALL || process.env.LC_MESSAGES || process.env.LANG || '';
  return rawLocale.toLowerCase().startsWith('de') ? 'de_de' : 'en_us';
}

function getDockBounds() {
  const display = screen.getPrimaryDisplay();
  const area = display.workArea;

  return {
    width: DOCK_WIDTH,
    height: DOCK_HEIGHT,
    x: Math.round(area.x + (area.width - DOCK_WIDTH) / 2),
    y: Math.round(area.y + area.height - DOCK_HEIGHT - DOCK_MARGIN)
  };
}

function launchDetached(command, args = []) {
  const child = spawn(command, args, {
    detached: true,
    env: process.env,
    stdio: 'ignore'
  });

  child.on('error', (error) => {
    logDock('launch failed', { command, args, error: formatLogValue(error) });
  });
  child.on('exit', (code, signal) => {
    if (code !== 0 || signal) {
      logDock('launch exited', { command, args, code, signal });
    }
  });
  child.unref();
  return { command, args };
}

function launchTerminal() {
  const launcher = '/usr/local/bin/tontoo-terminal';
  if (fs.existsSync(launcher)) {
    return launchDetached(launcher);
  }

  const appDir = '/usr/share/tontoo-terminal';
  if (!fs.existsSync(path.join(appDir, 'dist-electron/electron/main.js'))) {
    throw new Error(`Terminal app was not found at ${appDir}.`);
  }

  return launchDetached('/usr/bin/electron', ['--class=tontoo-terminal', '--no-sandbox', appDir]);
}

function launchSettings() {
  const launcher = '/usr/local/bin/tontoo-settings';
  if (fs.existsSync(launcher)) {
    return launchDetached(launcher);
  }

  const appDir = '/usr/share/tontoo-settings';
  if (!fs.existsSync(path.join(appDir, 'main.js'))) {
    throw new Error(`Settings app was not found at ${appDir}.`);
  }

  return launchDetached('/usr/bin/electron', ['--no-sandbox', appDir]);
}

function getDockApps() {
  return [
    readJson('apps/terminal/app.json'),
    readJson('apps/settings/app.json')
  ];
}

function createDockWindow() {
  const bounds = getDockBounds();
  logDock('creating dock window', bounds);

  dockWindow = new BrowserWindow({
    ...bounds,
    acceptFirstMouse: true,
    alwaysOnTop: true,
    backgroundColor: '#00000000',
    focusable: true,
    frame: false,
    fullscreenable: false,
    hasShadow: false,
    maximizable: false,
    minimizable: false,
    movable: false,
    resizable: false,
    show: false,
    skipTaskbar: true,
    title: 'Tontoo Dock',
    transparent: true,
    type: 'dock',
    webPreferences: {
      backgroundThrottling: false,
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'preload.js')
    }
  });

  dockWindow.removeMenu();
  dockWindow.setBackgroundColor('#00000000');
  if (typeof dockWindow.setHasShadow === 'function') {
    dockWindow.setHasShadow(false);
  }
  dockWindow.setAlwaysOnTop(true, 'floating');
  dockWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  dockWindow.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL) => {
    logDock('did-fail-load', { errorCode, errorDescription, validatedURL });
  });
  dockWindow.webContents.on('render-process-gone', (_event, details) => {
    logDock('render-process-gone', details);
  });
  dockWindow.on('closed', () => {
    logDock('dock window closed');
    dockWindow = null;
  });
  dockWindow.loadFile(path.join(__dirname, 'index.html')).catch((error) => {
    logDock('loadFile failed', error);
  });
  dockWindow.once('ready-to-show', () => {
    logDock('dock window ready-to-show');
    dockWindow.showInactive();
  });

  screen.on('display-metrics-changed', () => {
    if (dockWindow && !dockWindow.isDestroyed()) {
      const nextBounds = getDockBounds();
      logDock('display metrics changed', nextBounds);
      dockWindow.setBounds(nextBounds);
    }
  });
}

ipcMain.handle('dock:get-state', () => {
  const locale = detectLocale();
  return {
    locale,
    strings: readJson(`lang/${locale}.json`),
    apps: getDockApps()
  };
});

ipcMain.handle('dock:launch', (_event, appId) => {
  if (appId === 'terminal') {
    return launchTerminal();
  }

  if (appId === 'settings') {
    return launchSettings();
  }

  throw new Error(`Unknown dock app: ${appId}`);
});

process.on('uncaughtException', (error) => {
  logDock('uncaughtException', error);
});

process.on('unhandledRejection', (reason) => {
  logDock('unhandledRejection', reason);
});

app.whenReady().then(() => {
  logDock('starting dock app');
  createDockWindow();
}).catch((error) => {
  logDock('failed to start dock app', error);
  app.exit(1);
});

app.on('window-all-closed', (event) => {
  if (event && typeof event.preventDefault === 'function') {
    event.preventDefault();
  }
  logDock('window-all-closed ignored');
});
