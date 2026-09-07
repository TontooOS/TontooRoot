const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('tontooDock', {
  getState: () => ipcRenderer.invoke('dock:get-state'),
  launch: (appId) => ipcRenderer.invoke('dock:launch', appId)
});
