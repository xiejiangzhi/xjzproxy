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
      if (data.html || data.html == 0) {
        $html = $($.parseHTML(data.html.toString()));
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
      case 'el.set_attr':
        switch (data.attr) {
        case 'checked':
        case 'selected':
          $el[0][data.attr] = data.value
          break;
        default:
          if (data.value) {
            $el.attr(data.attr, data.value)
          } else {
            $el.removeAttr(data.attr)
          }
        }
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

      var that = this;
      window.setInterval(function(){
        if ($('#navbar_total_conns').html() > 0) {
          that.ws.sendMsg('history.update_total_proxy_conns', {})
        }
      }, 3000)
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

      var input_cb = this.formatEventCallback(function(evt, xjz_id, $el) {
        var el = $el[0]
        var val = $el.data('value');
        if (val && val != ''){
          // use data-value
        } else if (el.type == 'checkbox') {
          val = el.checked
        } else {
          val = $el.val()
        }
        this.ws.sendMsg(xjz_id + '.' + evt.type, {
          value: val, name: $el.data('name') || $el.attr('name')
        })
      })

      this.$container.on(
        'change',
        '[xjz-id][xjz-bind~=change], input[xjz-id], textarea[xjz-id], select[xjz-id]',
        input_cb
      )
      var keyup_delay = 500;
      var keyup_timer = null;
      this.$container.on('keyup', 'input[xjz-id][xjz-bind~=keyup]', function(evt) {
        if (keyup_timer) { window.clearTimeout(keyup_timer); }
        keyup_timer = window.setTimeout(function(){ input_cb(evt); }, keyup_delay);
      })

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

      this.$container.on('click', '[data-toggle=deep-list]', function(evt) {
        var $el = $(evt.currentTarget)
        var $parent = $($el.data('parent'))
        $parent.find('.active[data-toggle=deep-list]').removeClass('active');
        $el.addClass('active');
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
      $container.find('[title][data-toggle=popover]').popover();
      $container.find('[data-spy="scroll"]').each(function(i, el) {
        var $el = $(el);
        $el.scrollspy($(el).data());
      })
      $container.find('pre code').each(function(i, el) {
        hljs.highlightBlock(el);
      });
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
