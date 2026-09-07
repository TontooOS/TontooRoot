const dock = document.querySelector('#dock');

function resolveKey(strings, key) {
  return key.split('.').reduce((value, part) => value?.[part], strings) || key;
}

function pressAnimation(button) {
  button.classList.remove('is-pressed');
  requestAnimationFrame(() => {
    button.classList.add('is-pressed');
    window.setTimeout(() => button.classList.remove('is-pressed'), 260);
  });
}

function renderApp(app, strings) {
  const button = document.createElement('button');
  const label = resolveKey(strings, app.nameKey);
  let lastPointerLaunch = 0;

  button.className = 'dock-item';
  button.type = 'button';
  button.title = label;
  button.setAttribute('aria-label', label);

  const icon = document.createElement('img');
  icon.className = 'dock-icon';
  icon.src = app.icon;
  icon.alt = '';
  icon.draggable = false;

  const runningDot = document.createElement('span');
  runningDot.className = 'running-dot';

  const tooltip = document.createElement('span');
  tooltip.className = 'dock-tooltip';
  tooltip.textContent = label;

  button.append(icon, runningDot, tooltip);

  async function launchFromDock() {
    pressAnimation(button);
    button.classList.add('is-launching');
    try {
      await window.tontooDock.launch(app.id);
    } finally {
      window.setTimeout(() => button.classList.remove('is-launching'), 420);
    }
  }

  button.addEventListener('pointerenter', () => {
    button.classList.add('is-hovered');
  });

  button.addEventListener('pointerleave', () => {
    button.classList.remove('is-hovered');
  });

  button.addEventListener('pointerdown', async (event) => {
    if (event.button !== 0) {
      return;
    }

    event.preventDefault();
    lastPointerLaunch = Date.now();
    await launchFromDock();
  });

  button.addEventListener('click', async (event) => {
    if (Date.now() - lastPointerLaunch < 500) {
      event.preventDefault();
      return;
    }

    await launchFromDock();
  });

  return button;
}

async function boot() {
  const state = await window.tontooDock.getState();
  document.documentElement.lang = state.locale === 'de_de' ? 'de' : 'en';
  dock.replaceChildren(...state.apps.map((app) => renderApp(app, state.strings)));
}

boot().catch((error) => {
  console.error(error);
});
