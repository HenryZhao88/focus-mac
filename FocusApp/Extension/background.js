const WS_URL = 'ws://localhost:54321';
const MAX_BACKOFF = 30000;

let ws = null;
let backoff = 1000;
let reconnectTimer = null;

function connect() {
  if (ws && (ws.readyState === WebSocket.CONNECTING || ws.readyState === WebSocket.OPEN)) return;

  ws = new WebSocket(WS_URL);

  ws.onopen = () => {
    console.log('[FocusGuard] Connected to Focus app');
    backoff = 1000;
    sendCurrentTab();
  };

  ws.onclose = () => {
    console.log('[FocusGuard] Disconnected. Reconnecting in', backoff, 'ms');
    scheduleReconnect();
  };

  ws.onerror = (err) => {
    console.log('[FocusGuard] WebSocket error:', err);
  };
}

function scheduleReconnect() {
  clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(() => {
    backoff = Math.min(backoff * 2, MAX_BACKOFF);
    connect();
  }, backoff);
}

function send(url) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(url || 'null');
  }
}

async function sendCurrentTab() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    send(tab?.url || 'null');
  } catch (e) {
    send('null');
  }
}

// Send URL on tab activation
chrome.tabs.onActivated.addListener(() => sendCurrentTab());

// Send URL when tab URL changes
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url && tab.active) {
    send(tab.url);
  }
});

// Send URL when window focus changes
chrome.windows.onFocusChanged.addListener(() => sendCurrentTab());

// Initial connection
connect();

// Respond to popup status queries
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'getStatus') {
    sendResponse({ connected: ws?.readyState === WebSocket.OPEN });
  }
  return true;
});
