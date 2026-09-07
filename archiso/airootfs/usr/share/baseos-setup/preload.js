const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('setupAPI', {
  installerAvailable: true,
  listHarddrives: () => ipcRenderer.invoke('list-harddrives'),
  startInstall: (settings) => ipcRenderer.invoke('start-install', settings),
  tryLiveDesktop: () => ipcRenderer.invoke('try-live-desktop'),
  onInstallLog: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on('install-log', listener);
    return () => ipcRenderer.removeListener('install-log', listener);
  },
  onInstallProgress: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on('install-progress', listener);
    return () => ipcRenderer.removeListener('install-progress', listener);
  },
  onInstallFinished: (callback) => {
    const listener = (_event, payload) => callback(payload);
    ipcRenderer.on('install-finished', listener);
    return () => ipcRenderer.removeListener('install-finished', listener);
  }
});
