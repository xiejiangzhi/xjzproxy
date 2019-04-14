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
      case 'el.replace':
        $(data.selector).replaceWith(data.html);
        break;
      case 'el.remove':
        $(data.selector).remove();
        break;
      // case 'alert':
      //   $('#alerts').append(data.html);
      //   break;
      case 'hello':
        break;
      default: 
        console.log("Cannot handle msg type " + type);
      }
    },

    initView: function(evt) {
      console.log("Init View", evt)

      this.initEvents();
      this.initRPC();
    },

    initEvents: function() {
      this.$container.on(
        'click', '[xjz-id][xjz-bind~=click], a[xjz-id], button[xjz-id], .btn[xjz-id]',
        this.formatEventCallback(function(evt, xjz_id) {
          this.ws.sendMsg(xjz_id + '.' + evt.type)
        })
      )

      this.$container.on(
        'change', '[xjz-id][xjz-bind~=change], input[xjz-id], textarea[xjz-id], select[xjz-id]',
        this.formatEventCallback(function(evt, xjz_id, $el) {
          var el = $el[0]
          var val = $el.attr('xjz-value');
          if (val && val != ''){
            // nothing
          } else if (el.type == 'checkbox' || el.type == 'radio') { val = el.checked }
          else { val = $el.val() }
          this.ws.sendMsg(xjz_id + '.' + evt.type, { value: val } )
        })
      )

      this.$container.on('click', '[xjz-rpc]', this.formatEventCallback(function(evt, xjz_id, $el) {
        var rpc_data = $el.attr('xjz-rpc') + ',' + xjz_id;
        console.log("Invoke RPC '" + rpc_data + "'");
        window.external.invoke(rpc_data);
      }))

      // this.$container.on('click', '#app_header .nav-item', function(evt) {
      //   console.log('asdf')
      //   debugger
      // })
    },

    initRPC: function() {
      var update_input_val_by_xjz_id = this.newRPCCallback(function(value, xjz_id) {
        if (!value || value == '') { return }
        $("[xjz-id='" + xjz_id + "']").val(value).change();
      })

      window.rpc = {
        openfile_cb: update_input_val_by_xjz_id,
        opendir_cb: update_input_val_by_xjz_id,
        open_cb: update_input_val_by_xjz_id,
        error: function(action, user_data) {
          console.error("Invalid action: '" + action + "' with userdata '" + user_data + "'")
        }
      }
    },

    formatEventCallback: function(cb) {
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
    },

    newRPCCallback: function(cb) {
      var that = this;
      return function(val, user_data) {
        console.log("RPC callback '" + val + "' with data '" + user_data + "'");
        cb.apply(that, [val, user_data]);
      }
    }
  }

  window.XjzView = XjzView;
})()
