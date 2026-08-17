"""The five wizard pages: locale, keyboard, partitioning, hostname/user, progress."""

import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gtk

import backend

DEFAULT_TIMEZONE = "America/New_York"
DEFAULT_LOCALE = "en_US.UTF-8"
DEFAULT_KEYMAP = "us"


def _string_list(items):
    model = Gtk.StringList()
    for item in items:
        model.append(item)
    return model


class LocalePage(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Locale")
        group = Adw.PreferencesGroup(
            title="Locale", description="Timezone and system language"
        )
        self.add(group)

        timezones = self._list_timezones()
        self.timezone_row = Adw.ComboRow(title="Timezone", model=_string_list(timezones))
        if DEFAULT_TIMEZONE in timezones:
            self.timezone_row.set_selected(timezones.index(DEFAULT_TIMEZONE))
        group.add(self.timezone_row)

        locales = self._list_locales()
        self.locale_row = Adw.ComboRow(title="Language", model=_string_list(locales))
        if DEFAULT_LOCALE in locales:
            self.locale_row.set_selected(locales.index(DEFAULT_LOCALE))
        group.add(self.locale_row)

    @staticmethod
    def _list_timezones():
        try:
            out = subprocess.run(
                ["timedatectl", "list-timezones"], check=True, capture_output=True, text=True
            ).stdout
            zones = [line for line in out.splitlines() if line]
            return zones or [DEFAULT_TIMEZONE]
        except (subprocess.CalledProcessError, FileNotFoundError):
            return [DEFAULT_TIMEZONE]

    @staticmethod
    def _list_locales():
        try:
            locales = []
            with open("/etc/locale.gen") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("#") and "UTF-8" in line:
                        locales.append(line.lstrip("#").split()[0])
            return locales or [DEFAULT_LOCALE]
        except OSError:
            return [DEFAULT_LOCALE]

    def selected_timezone(self):
        return self.timezone_row.get_selected_item().get_string()

    def selected_locale(self):
        return self.locale_row.get_selected_item().get_string()


class KeyboardPage(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Keyboard")
        group = Adw.PreferencesGroup(title="Keyboard layout")
        self.add(group)

        layouts = self._list_layouts()
        self.layout_row = Adw.ComboRow(title="Layout", model=_string_list(layouts))
        if DEFAULT_KEYMAP in layouts:
            self.layout_row.set_selected(layouts.index(DEFAULT_KEYMAP))
        group.add(self.layout_row)

    @staticmethod
    def _list_layouts():
        try:
            out = subprocess.run(
                ["localectl", "list-keymaps"], check=True, capture_output=True, text=True
            ).stdout
            layouts = [line for line in out.splitlines() if line]
            return layouts or [DEFAULT_KEYMAP]
        except (subprocess.CalledProcessError, FileNotFoundError):
            return [DEFAULT_KEYMAP]

    def selected_layout(self):
        return self.layout_row.get_selected_item().get_string()


class PartitionPage(Adw.PreferencesPage):
    CONFIRM_TEXT = "ERASE"

    def __init__(self):
        super().__init__(title="Partitioning")
        group = Adw.PreferencesGroup(
            title="Disk",
            description=(
                "The selected disk will be completely erased and repartitioned. "
                "This cannot be undone."
            ),
        )
        self.add(group)

        self.disks = backend.list_disks()
        labels = [self._label(d) for d in self.disks] or ["No disks found"]
        self.disk_row = Adw.ComboRow(title="Target disk", model=_string_list(labels))
        group.add(self.disk_row)

        self.confirm_row = Adw.EntryRow(title=f'Type "{self.CONFIRM_TEXT}" to confirm')
        group.add(self.confirm_row)

    @staticmethod
    def _label(disk):
        size_gib = disk["size"] / (1024**3)
        model = f" ({disk['model']})" if disk["model"] else ""
        return f"{disk['path']}{model} — {size_gib:.0f} GiB"

    def selected_disk(self):
        if not self.disks:
            return None
        return self.disks[self.disk_row.get_selected()]["path"]

    def is_confirmed(self):
        return (
            self.selected_disk() is not None
            and self.confirm_row.get_text().strip() == self.CONFIRM_TEXT
        )


class UsersPage(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Hostname & User")
        group = Adw.PreferencesGroup(title="Hostname and user account")
        self.add(group)

        self.hostname_row = Adw.EntryRow(title="Hostname")
        self.hostname_row.set_text("fenrir")
        group.add(self.hostname_row)

        self.fullname_row = Adw.EntryRow(title="Full name")
        group.add(self.fullname_row)

        self.username_row = Adw.EntryRow(title="Username")
        group.add(self.username_row)

        self.password_row = Adw.PasswordEntryRow(title="Password")
        group.add(self.password_row)

        self.password_confirm_row = Adw.PasswordEntryRow(title="Confirm password")
        group.add(self.password_confirm_row)

    def is_valid(self):
        return (
            bool(self.hostname_row.get_text().strip())
            and bool(self.username_row.get_text().strip())
            and bool(self.password_row.get_text())
            and self.password_row.get_text() == self.password_confirm_row.get_text()
        )

    def values(self):
        return {
            "hostname": self.hostname_row.get_text().strip(),
            "full_name": self.fullname_row.get_text().strip() or self.username_row.get_text().strip(),
            "username": self.username_row.get_text().strip(),
            "password": self.password_row.get_text(),
        }


class ProgressPage(Gtk.Box):
    def __init__(self):
        super().__init__(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=12,  # Tokens.spacing.normal
            margin_top=20,  # Tokens.spacing.large
            margin_bottom=20,
            margin_start=20,
            margin_end=20,
        )

        self.status_label = Gtk.Label(label="Installing Fenrir…", xalign=0)
        self.status_label.add_css_class("title-2")
        self.append(self.status_label)

        scrolled = Gtk.ScrolledWindow(vexpand=True)
        self.text_view = Gtk.TextView(editable=False, monospace=True)
        scrolled.set_child(self.text_view)
        self.append(scrolled)

    def log(self, line):
        buf = self.text_view.get_buffer()
        buf.insert(buf.get_end_iter(), line + "\n")
        self.text_view.scroll_to_mark(buf.get_insert(), 0.0, False, 0.0, 0.0)

    def set_status(self, text):
        self.status_label.set_label(text)
