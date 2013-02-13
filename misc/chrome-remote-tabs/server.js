var socket;
var backoff = defaultBackoff = 500, maxBackoff = 60000;

function sendArg(req) {
  return function() {
    socket.send(JSON.stringify({'id': req.id, 'data': arguments[0]}));
  }
}

function connect() {
  socket = new WebSocket("ws://localhost:3000/");
  console.log("Connecting: ", socket);

  socket.onopen = function() {
    backoff = defaultBackoff;
  }

  socket.onmessage = function(e) {
    var req = JSON.parse(e.data);
    switch(req.t) {
      case "windows":
        chrome.windows.getAll(null, sendArg(req));
        break;
      case "tabs":
        chrome.tabs.getAllInWindow(req.windowId, sendArg(req));
        break;
      case "focus":
        sendArg(req)(chrome.tabs.update(req.tabId, {'selected': true}));
        break;
    }
  }
  socket.onclose = function() {
    if(backoff < maxBackoff) {
      backoff *= 2;
    }
    setTimeout(connect, backoff);
  }
}

connect();
