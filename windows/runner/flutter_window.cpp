#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Static member definitions
HHOOK FlutterWindow::keyboard_hook_ = nullptr;
flutter::EventSink<flutter::EncodableValue>* FlutterWindow::event_sink_ = nullptr;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupKeyboardChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetupKeyboardChannel() {
  keyboard_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.kysy/keyboard_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          // onListen: Dart starts subscribing
          [](const flutter::EncodableValue* /*args*/,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = events.release();
            keyboard_hook_ = SetWindowsHookEx(
                WH_KEYBOARD_LL, LowLevelKeyboardProc,
                GetModuleHandle(nullptr), 0);
            return nullptr;
          },
          // onCancel: Dart unsubscribes
          [](const flutter::EncodableValue* /*args*/)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            if (keyboard_hook_) {
              UnhookWindowsHookEx(keyboard_hook_);
              keyboard_hook_ = nullptr;
            }
            delete event_sink_;
            event_sink_ = nullptr;
            return nullptr;
          });

  keyboard_channel_->SetStreamHandler(std::move(handler));
}

LRESULT CALLBACK FlutterWindow::LowLevelKeyboardProc(int nCode,
                                                      WPARAM wParam,
                                                      LPARAM lParam) {
  if (nCode >= 0 && event_sink_ != nullptr) {
    auto* kb = reinterpret_cast<KBDLLHOOKSTRUCT*>(lParam);
    bool is_key_down = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);

    flutter::EncodableMap mods = {
        {flutter::EncodableValue("shift"),
         flutter::EncodableValue((GetKeyState(VK_SHIFT) & 0x8000) != 0)},
        {flutter::EncodableValue("ctrl"),
         flutter::EncodableValue((GetKeyState(VK_CONTROL) & 0x8000) != 0)},
        {flutter::EncodableValue("alt"),
         flutter::EncodableValue((GetKeyState(VK_MENU) & 0x8000) != 0)},
        {flutter::EncodableValue("meta"),
         flutter::EncodableValue(
             (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
             (GetKeyState(VK_RWIN) & 0x8000) != 0)},
    };

    flutter::EncodableMap payload = {
        {flutter::EncodableValue("keyCode"),
         flutter::EncodableValue(static_cast<int>(kb->vkCode))},
        {flutter::EncodableValue("scanCode"),
         flutter::EncodableValue(static_cast<int>(kb->scanCode))},
        {flutter::EncodableValue("isKeyDown"),
         flutter::EncodableValue(is_key_down)},
        {flutter::EncodableValue("modifiers"),
         flutter::EncodableValue(mods)},
        {flutter::EncodableValue("timestamp"),
         flutter::EncodableValue(static_cast<double>(kb->time))},
    };

    event_sink_->Success(flutter::EncodableValue(payload));
  }
  return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

void FlutterWindow::OnDestroy() {
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
  delete event_sink_;
  event_sink_ = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                       WPARAM const wparam,
                                       LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
