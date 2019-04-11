(function(){
  var valid_events = {
    open: true,
    close: true,
    error: true,
    message: true
  }

  function XjzWebSocket(url) {
    this.url = url;
    var ws = this;
    this.events = {};
    this.websocket = new WebSocket(url);
    this.websocket.onopen = function(evt) { ws.emit('open', [evt]); };
    this.websocket.onclose = function(evt) { ws.emit('close', [evt]); };
    this.websocket.onerror = function(evt) { ws.emit('error', [evt]); };
    this.websocket.onmessage = function(evt) { onMessage(evt, ws) };
  }

  XjzWebSocket.prototype = {
    sendMsg: function (event, data) {
      this.websocket.send(JSON.stringify({ type: event, data: data }));
    },
    emit: function(name, data) {
      verifyEventName(name)
      var cb = this.events[name];
      if (cb) { cb.apply(null, data) }
    },
    on: function(name, cb) {
      verifyEventName(name)
      this.events[name] = cb;
    }
  }

  function onMessage(evt, ws) {
    var msg = JSON.parse(evt.data);
    console.log(evt);
    ws.emit('message', [msg.type, msg.data]);
  }

  function verifyEventName(name) {
    if (valid_events[name]) {
      return true;
    } else {
      throw "Invalid event name '" + name + "'";
    }
  }

  window.XjzWebSocket = XjzWebSocket
})()

