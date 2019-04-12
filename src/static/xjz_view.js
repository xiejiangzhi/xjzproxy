(function(){
  var XjzView = function(ws_url, container){
    this.ws = new window.XjzWebSocket(ws_url)
    var that = this;
    this.ws.on('open', function(evt) { that.initView(evt) })
    this.ws.on('error', function(evt) { that.onError(evt) });
    this.ws.on('close', function(evt) { that.onClose(evt) });
    this.ws.on('message', function(type, data) { that.onMessage(type, data) });
    this.$container = $(container);
  }
  
  XjzView.prototype = {
    onError: function() {
      console.log("Error")
    },

    onClose: function() {
      console.log("Close")
    },

    onMessage: function(type, data){
      switch (type) {
      case 'el.append':
        $(data.selector).append(data.html);
        break;
      case 'el.after':
        $(data.selector).after(data.html);
        break;
      case 'el.html':
        $(data.selector).html(data.html);
        break;
      case 'el.remove':
        $(data.selector).remove();
        break;
      case 'alert':
        $('#alerts').append(data.html);
        break;
      case 'hello':
        break;
      default: 
        console.log("Cannot handle msg type " + type);
      }
    },

    initView: function(evt) {
      console.log("Init View", evt)
      var that = this;
      this.$container.on('click change', '[xjz-id]', function(evt) {
        that.sendElemEvent(evt.type, evt.currentTarget);
      })
    },

    sendElemEvent: function(type, el) {
      var xjz_id = $(el).attr('xjz-id');
      if (xjz_id && xjz_id != '') {
        this.ws.sendMsg(xjz_id + '.' + type)
      }
    }
  }

  window.XjzView = XjzView;
})()
