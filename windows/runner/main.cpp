#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <tlhelp32.h>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

static std::vector<DWORD> GetOtherAttendanceAppPids(DWORD currentPid) {
  std::vector<DWORD> pids;
  HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(PROCESSENTRY32W);
    if (::Process32FirstW(snapshot, &entry)) {
      do {
        if (_wcsicmp(entry.szExeFile, L"attendance_app.exe") == 0) {
          if (entry.th32ProcessID != currentPid) {
            pids.push_back(entry.th32ProcessID);
          }
        }
      } while (::Process32NextW(snapshot, &entry));
    }
    ::CloseHandle(snapshot);
  }
  return pids;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool start_hidden = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--silent" || arg == "--background") {
      start_hidden = true;
      break;
    }
  }

  DWORD currentPid = ::GetCurrentProcessId();
  std::vector<DWORD> existingPids = GetOtherAttendanceAppPids(currentPid);

  if (!existingPids.empty()) {
    if (start_hidden) {
      // If a background service is starting, but one is already running, exit cleanly
      ::CoUninitialize();
      return EXIT_SUCCESS;
    } else {
      // User launched the GUI app!
      // Terminate any existing background worker so GUI opens immediately with zero lock errors
      for (DWORD pidToKill : existingPids) {
        HANDLE hProc = ::OpenProcess(PROCESS_TERMINATE, FALSE, pidToKill);
        if (hProc) {
          ::TerminateProcess(hProc, 0);
          ::CloseHandle(hProc);
        }
      }
      ::Sleep(350);
    }
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Amada", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
