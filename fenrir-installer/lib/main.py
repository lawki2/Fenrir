"""Wizard window: wires the five pages together with Back/Next navigation
and kicks off the background install thread."""

import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk

import backend
import theme
from pages import KeyboardPage, LocalePage, PartitionPage, ProgressPage, UsersPage

PAGE_ORDER = ["locale", "keyboard", "partition", "users", "progress"]


class FenrirInstallerWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(
            application=app, title="Install Fenrir", default_width=780, default_height=560
        )

        self.locale_page = LocalePage()
        self.keyboard_page = KeyboardPage()
        self.partition_page = PartitionPage()
        self.users_page = UsersPage()
        self.progress_page = ProgressPage()

        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.add_named(self.locale_page, "locale")
        self.stack.add_named(self.keyboard_page, "keyboard")
        self.stack.add_named(self.partition_page, "partition")
        self.stack.add_named(self.users_page, "users")
        self.stack.add_named(self.progress_page, "progress")

        header = Adw.HeaderBar()

        self.back_button = Gtk.Button(label="Back")
        self.back_button.connect("clicked", self._on_back)
        header.pack_start(self.back_button)

        self.next_button = Gtk.Button(label="Next")
        self.next_button.add_css_class("suggested-action")
        self.next_button.connect("clicked", self._on_next)
        header.pack_end(self.next_button)

        toolbar_view = Adw.ToolbarView()
        toolbar_view.add_top_bar(header)
        toolbar_view.set_content(self.stack)

        self.set_content(toolbar_view)

        self._apply_theme()
        self._update_nav()

    def _apply_theme(self):
        css = theme.build_css()
        if not css:
            return
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            self.get_display(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _current_index(self):
        return PAGE_ORDER.index(self.stack.get_visible_child_name())

    def _update_nav(self):
        index = self._current_index()
        name = PAGE_ORDER[index]
        self.back_button.set_visible(0 < index < len(PAGE_ORDER) - 1)
        if name == "users":
            self.next_button.set_label("Install")
            self.next_button.set_visible(True)
        elif name == "progress":
            self.next_button.set_visible(False)
        else:
            self.next_button.set_label("Next")
            self.next_button.set_visible(True)

    def _on_back(self, _button):
        index = self._current_index()
        if index > 0:
            self.stack.set_visible_child_name(PAGE_ORDER[index - 1])
            self._update_nav()

    def _on_next(self, _button):
        index = self._current_index()
        current = PAGE_ORDER[index]

        if current == "partition" and not self.partition_page.is_confirmed():
            self._show_error("Select a disk and type ERASE to confirm.")
            return
        if current == "users" and not self.users_page.is_valid():
            self._show_error("Fill in every field; the two passwords must match.")
            return

        if current == "users":
            self.stack.set_visible_child_name("progress")
            self._update_nav()
            self._start_install()
            return

        if index < len(PAGE_ORDER) - 1:
            self.stack.set_visible_child_name(PAGE_ORDER[index + 1])
            self._update_nav()

    def _show_error(self, message):
        dialog = Adw.AlertDialog(heading="Can't continue", body=message)
        dialog.add_response("ok", "OK")
        dialog.present(self)

    def _start_install(self):
        values = self.users_page.values()
        plan = backend.InstallPlan(
            disk=self.partition_page.selected_disk(),
            esp_mib=4096,
            timezone=self.locale_page.selected_timezone(),
            locale=self.locale_page.selected_locale(),
            keyboard=self.keyboard_page.selected_layout(),
            hostname=values["hostname"],
            full_name=values["full_name"],
            username=values["username"],
            password=values["password"],
        )

        def progress(line):
            # Also printed to stdout (not just the on-screen log) so
            # install output shows up wherever the launcher's own output
            # is captured, same as every other step of testing this ISO.
            print(line, flush=True)
            GLib.idle_add(self.progress_page.log, line)
            return False

        def worker():
            try:
                backend.run_install(plan, progress)
                GLib.idle_add(
                    self.progress_page.set_status, "Install complete. You can reboot now."
                )
            except backend.InstallError as exc:
                GLib.idle_add(self.progress_page.set_status, f"Install failed: {exc}")

        threading.Thread(target=worker, daemon=True).start()


class FenrirInstallerApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="dev.fenrir.Installer")

    def do_activate(self):
        window = self.props.active_window
        if not window:
            window = FenrirInstallerWindow(self)
        window.present()


def run():
    app = FenrirInstallerApp()
    app.run()
