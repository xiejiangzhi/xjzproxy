// webview commit 2019-1-23 16c93bcaeaeb6aa7bb5a1432de3bef0b9ecc44f3

package main

import "github.com/zserge/webview"
import "flag"
import "fmt"
import "os"
import "strings"

func EvalCallback(w webview.WebView, name string, data string) {
  data = strings.ReplaceAll(data, "'", "\\'")
	w.Eval(fmt.Sprintf(`
    (function(){
      if (!window.rpc) { return }
      var cb = window.rpc.%s_cb
      if (!cb) { return }
      cb('%s')
    })()
  `, name, data))
}

func handleRPC(w webview.WebView, data string) {
	switch {
	case data == "close":
		w.Terminate()
	case data == "fullscreen":
		w.SetFullscreen(true)
	case data == "unfullscreen":
		w.SetFullscreen(false)
  case data == "openfile":
    path := w.Dialog(webview.DialogTypeOpen, 0, "Select a file", "")
    EvalCallback(w, "openfile", path)
	case data == "opendir":
    path := w.Dialog(webview.DialogFlagDirectory, 0, "Select a directory", "")
    EvalCallback(w, "opendir", path)
  }
}
func main() {
  urlPtr := flag.String("url", "", "App URL")
  titlePtr := flag.String("title", "XJZProxy", "App title")
  widthPtr := flag.Int("width", 1100, "width of window")
  heightPtr := flag.Int("height", 800, "height of window")
  debugPtr := flag.Bool("debug", false, "debug mode")
  resizablePtr := flag.Bool("resizable", false, "Allow resize window")

  flag.Parse()

  if *urlPtr == "" {
    fmt.Fprintf(os.Stderr, "URL is required\n")
    os.Exit(1)
  }

  w := webview.New(webview.Settings{
		URL: *urlPtr,
		Title: *titlePtr,
		Width: *widthPtr,
		Height: *heightPtr,
		Resizable: *resizablePtr,
    Debug: *debugPtr,
    ExternalInvokeCallback: handleRPC,
	})
  defer w.Exit()
  w.Run()
}
