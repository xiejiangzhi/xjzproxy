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
      window.close()
    },

    onClose: function() {
      window.close()
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
      this.$container.on('click', '[xjz-id]', this.formatEvent(function(evt, xjz_id) {
        this.ws.sendMsg(xjz_id + '.' + evt.type)
      }))
      this.$container.on('change', '[xjz-id]', this.formatEvent(function(evt, xjz_id, $el) {
        this.ws.sendMsg(xjz_id + '.' + evt.type, { value: $el.val() } )
      }))
    },

    formatEvent: function(cb) {
      var that = this;
      return function(evt) {
        var $el = $(evt.currentTarget);
        var xjz_id = $el.attr('xjz-id');
        if (xjz_id && xjz_id != '') {
          cb.apply(that, [evt, xjz_id, $el])
        } else {
          console.error("Invalid element", evt)
        }
      }
    }
  }

  window.XjzView = XjzView;
})()
