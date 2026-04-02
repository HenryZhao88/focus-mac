// Check WebSocket connection status from the background service worker
chrome.runtime.sendMessage({ type: 'getStatus' }, (response) => {
  const dot = document.getElementById('dot');
  const label = document.getElementById('label');
  if (response?.connected) {
    dot.className = 'dot connected';
    label.textContent = 'Connected to Focus';
  } else {
    dot.className = 'dot disconnected';
    label.textContent = 'Focus app not running';
  }
});
