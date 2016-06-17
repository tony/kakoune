#ifndef client_hh_INCLUDED
#define client_hh_INCLUDED

#include "display_buffer.hh"
#include "env_vars.hh"
#include "input_handler.hh"
#include "safe_ptr.hh"
#include "utils.hh"
#include "option_manager.hh"
#include "enum.hh"
#include "user_interface.hh"

namespace Kakoune
{

class ClientManager;
class Window;
class String;
struct Key;

enum class EventMode;

class Client : public SafeCountable, public OptionManagerWatcher
{
 public:
    Client(ClientManager& client_manager,
           std::unique_ptr<UserInterface>&& ui,
           std::unique_ptr<Window>&& window,
           SelectionList selections,
           EnvVarMap env_vars,
           String name);
    ~Client();

    Client(Client&&) = delete;

    // handle all the keys currently available in the user interface
    void handle_available_input(EventMode mode);

    void menu_show(Vector<DisplayLine> choices, ByteCoord anchor, MenuStyle style);
    void menu_select(int selected);
    void menu_hide();

    void info_show(String title, String content, ByteCoord anchor, InfoStyle style);
    void info_hide();

    void print_status(DisplayLine status_line);

    CharCoord dimensions() const { return m_ui->dimensions(); }

    void force_redraw();
    void redraw_ifn();

    void check_if_buffer_needs_reloading();

    Context& context() { return m_input_handler.context(); }
    const Context& context() const { return m_input_handler.context(); }

    InputHandler& input_handler() { return m_input_handler; }
    const InputHandler& input_handler() const { return m_input_handler; }

    void change_buffer(Buffer& buffer);

    StringView get_env_var(StringView name) const;

    Buffer* last_buffer() const { return m_last_buffer.get(); }
    void set_last_buffer(Buffer* last_buffer) { m_last_buffer = last_buffer; }

private:
    void on_option_changed(const Option& option) override;

    void on_buffer_reload_key(Key key);
    void close_buffer_reload_dialog();
    void reload_buffer();

    Optional<Key> get_next_key(EventMode mode);

    DisplayLine generate_mode_line() const;

    std::unique_ptr<UserInterface> m_ui;
    std::unique_ptr<Window> m_window;

    EnvVarMap m_env_vars;

    InputHandler m_input_handler;

    DisplayLine m_status_line;
    DisplayLine m_mode_line;

    enum PendingUI : int
    {
        MenuShow   = 1 << 0,
        MenuSelect = 1 << 1,
        MenuHide   = 1 << 2,
        InfoShow   = 1 << 3,
        InfoHide   = 1 << 4,
        StatusLine = 1 << 5,
        Draw       = 1 << 6,
        Refresh    = 1 << 7,
    };
    int m_ui_pending = 0;

    struct Menu
    {
        Vector<DisplayLine> items;
        ByteCoord anchor;
        CharCoord ui_anchor;
        MenuStyle style;
        int selected;
    } m_menu;

    struct Info
    {
        String title;
        String content;
        ByteCoord anchor;
        CharCoord ui_anchor;
        InfoStyle style;
    } m_info;

    Vector<Key, MemoryDomain::Client> m_pending_keys;

    bool m_buffer_reload_dialog_opened = false;

    SafePtr<Buffer> m_last_buffer;
};

enum class Autoreload
{
    Yes,
    No,
    Ask
};

constexpr Array<EnumDesc<Autoreload>, 5> enum_desc(Autoreload)
{
    return { {
        { Autoreload::Yes, "yes" },
        { Autoreload::No, "no" },
        { Autoreload::Ask, "ask" },
        { Autoreload::Yes, "true" },
        { Autoreload::No, "false" }
    } };
}

}

#endif // client_hh_INCLUDED
