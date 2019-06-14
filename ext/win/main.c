#include "windows.h"

int WINAPI WinMain(
  HINSTANCE hInstance, HINSTANCE hPrevInstance, PSTR szCmdLine, int iCmdShow
) {

#if TEST
  char ruby[] = "..\\..\\releases\\mingw32-x64\\lib\\ruby\\bin\\ruby.cmd";
  char file[] = "test.rb";
#else
  char ruby[] = "lib\\ruby\\bin\\ruby.cmd";
  char file[] = "lib\\app\\boot";
#endif

  ShellExecute(NULL, "open", ruby, file, NULL, SW_HIDE);
  return 0;
}
