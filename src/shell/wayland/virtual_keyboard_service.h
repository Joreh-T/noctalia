#pragma once

#include <cstdint>

struct wl_seat;
struct wl_display;
struct zwp_virtual_keyboard_manager_v1;
struct zwp_virtual_keyboard_v1;
struct xkb_context;
struct xkb_keymap;

enum class VirtualPasteShortcut : std::uint8_t {
  CtrlV = 0,
  CtrlShiftV = 1,
  ShiftInsert = 2,
};

class VirtualKeyboardService {
public:
  VirtualKeyboardService();
  ~VirtualKeyboardService();

  VirtualKeyboardService(const VirtualKeyboardService&) = delete;
  VirtualKeyboardService& operator=(const VirtualKeyboardService&) = delete;

  bool bind(zwp_virtual_keyboard_manager_v1* manager, wl_seat* seat);
  // Ubuntu 24.04's libwayland 1.22 lacks wl_proxy_get_display(); the owning
  // WaylandConnection supplies its wl_display* so sendPasteShortcut can flush.
  void setDisplay(wl_display* display) noexcept;
  void cleanup();

  bool isAvailable() const noexcept;
  [[nodiscard]] bool sendPasteShortcut(VirtualPasteShortcut shortcut);

private:
  [[nodiscard]] bool ensureKeyboard();
  [[nodiscard]] bool ensureKeymap();
  void pressChord(std::uint32_t key, bool ctrlPressed, bool shiftPressed);
  void sendKey(std::uint32_t key, bool pressed);

  wl_display* m_display = nullptr;
  void updateModifiers(bool ctrlPressed, bool shiftPressed);

  zwp_virtual_keyboard_manager_v1* m_manager = nullptr;
  wl_seat* m_seat = nullptr;
  zwp_virtual_keyboard_v1* m_keyboard = nullptr;
  xkb_context* m_xkbContext = nullptr;
  xkb_keymap* m_xkbKeymap = nullptr;
  std::uint32_t m_ctrlMask = 0;
  std::uint32_t m_shiftMask = 0;
  bool m_keymapUploaded = false;
};
