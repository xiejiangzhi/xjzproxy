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
      var $el, $html;
      if (data.selector) { $el = $(data.selector); }
      if (data.html) {
        $html = $($.parseHTML(data.html));
        this.initElem($html);
      }

      switch (type) {
      case 'el.append':
        $el.append($html);
        break;
      case 'el.after':
        $el.after($html);
        break;
      case 'el.html':
        $el.html($html || '');
        break;
      case 'el.replace':
        $el.replaceWith($html);
        break;
      case 'el.remove':
        $el.remove();
        break;
      case 'alert':
        this.notify(data.message, data.type)
        break;
      case 'hello':
        break;
      default: 
        console.log("Cannot handle msg type " + type);
      }
    },

    initView: function() {
      console.log("Init View")

      this.initEvents();
      this.initDynamicEvents(this.$container);
      this.initRPC();
    },

    initEvents: function() {
      var that = this;
      this.$container.on(
        'click', '[xjz-id][xjz-bind~=click], a[xjz-id], button[xjz-id], .btn[xjz-id]',
        this.formatEventCallback(function(evt, xjz_id, $el) {
          this.ws.sendMsg(xjz_id + '.' + evt.type, {
            name: $el.data('name') || $el.attr('name')
          })
        })
      )

      this.$container.on(
        'change', '[xjz-id][xjz-bind~=change], input[xjz-id], textarea[xjz-id], select[xjz-id]',
        this.formatEventCallback(function(evt, xjz_id, $el) {
          var el = $el[0]
          var val = $el.data('value');
          if (val && val != ''){
            // nothing
          } else if (el.type == 'checkbox' || el.type == 'radio') { val = el.checked }
          else { val = $el.val() }
          this.ws.sendMsg(xjz_id + '.' + evt.type, {
            value: val, name: $el.data('name') || $el.attr('name')
          })
        })
      )

      this.$container.on('click', '[xjz-rpc]', function(evt) {
        var $el = $(evt.currentTarget);
        var type = $el.attr('xjz-rpc')
        var selector = $el[0].id;
        if (selector) { selector = '#' + selector; }
        else if ($el.attr('xjz-id')) { selector = '[xjz-id=' + $el.attr('xjz-id') + ']'; }
        else { throw("Cannot find RPC element id, need 'id' and 'xjz-id' attributes") }

        var rpc_data = type + ',' + selector;
        console.log("Invoke RPC '" + rpc_data + "'");
        window.external.invoke(rpc_data);
      })

      this.$container.on('click', '[xjz-action]', function(evt) {
        var $el = $(evt.currentTarget)
        var action = $el.attr('xjz-action')
        var args = $el.data('args') || []
        var $target = $($el.data('target'))
        $target[action].apply($target, args)
      })

      this.$container.on('click', '[xjz-notify]', function(evt) {
        var $el = $(evt.currentTarget)
        that.notify($el.attr('xjz-notify'), $el.data('notify-type'))
      })
    },

    initRPC: function() {
      window.rpc_cb = function(type, value, selector) {
        if (type == 'error') {
          console.error("Invalid RPC invoke with user data '" + selector + "'")
        } else {
          console.log("RPC callback '" + value + "' with data '" + selector + "'");
          if (!value || value == '') { return }
          var $el = $(selector)
          var $target = $el;
          if ($el.data('rpc-target')) { $target = $($el.data('rpc-target')) }
          $target.val(value).change();
        }
      }
    },

    initDynamicEvents: function($container) {
      $container.find('[title][data-toggle=tooltip]').tooltip();
    },

    initElem: function(html){
      var $el = $(html);
      this.initDynamicEvents($el);
      return $el;
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

    notify: function(text, type, delay) {
      new window.Noty({
        text: text,
        type: type || 'info',
        theme: 'bootstrap-v4',
        timeout: delay || 5000,
        layout: 'bottomRight'
      }).show()
    }
  }

  window.XjzView = XjzView;
})()
