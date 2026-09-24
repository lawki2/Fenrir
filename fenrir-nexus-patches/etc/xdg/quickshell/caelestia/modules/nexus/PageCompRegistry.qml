pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.desktop
import qs.modules.nexus.pages.firewall
import qs.modules.nexus.pages.keybinds
import qs.modules.nexus.pages.monitors
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.nightlight
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.power
import qs.modules.nexus.pages.printers
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.system
import qs.modules.nexus.pages.updates
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    readonly property list<Component> pageComps: [
        // Appearance
        Component {
            // Wallpaper & style
            StackPage {
                Component {
                    WallpaperAndStyle {}
                }
                Component {
                    WallpaperSelect {}
                }
                Component {
                    WallpaperCategory {}
                }
                Component {
                    ColourSelect {}
                }
            }
        },
        Component {
            // Desktop
            StackPage {
                Component {
                    DesktopPage {}
                }
            }
        },

        // Connectivity
        Component {
            // Display
            StackPage {
                Component {
                    MonitorsPage {}
                }
            }
        },
        Component {
            // Night light
            StackPage {
                Component {
                    NightLightPage {}
                }
            }
        },
        Component {
            // Network
            StackPage {
                Component {
                    NetworkPage {}
                }
                Component {
                    EthernetDetailPage {}
                }
                Component {
                    AddNetworkPage {}
                }
                Component {
                    NetworkDetailPage {}
                }
                Component {
                    AddVpnPage {}
                }
                Component {
                    AllNetworksPage {}
                }
                Component {
                    SavedNetworksPage {}
                }
            }
        },
        Component {
            // Firewall
            StackPage {
                Component {
                    FirewallPage {}
                }
            }
        },
        Component {
            // Bluetooth
            StackPage {
                Component {
                    BluetoothPage {}
                }
                Component {
                    BtDeviceInfo {}
                }
                Component {
                    BluetoothPairing {}
                }
            }
        },
        Component {
            // Printers
            StackPage {
                Component {
                    PrintersPage {}
                }
            }
        },
        Component {
            // Audio
            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },

        // System
        Component {
            // Power & sleep
            StackPage {
                Component {
                    PowerPage {}
                }
            }
        },
        Component {
            // Updates
            StackPage {
                Component {
                    UpdatesPage {}
                }
            }
        },
        Component {
            PlaceholderComp {}
        },

        // Shell
        Component {
            // Panels
            StackPage {
                Component {
                    PanelsPage {}
                }
                Component {
                    DashboardPanel {}
                }
                Component {
                    TaskbarPanel {}
                }
                Component {
                    LauncherPanel {}
                }
                Component {
                    SidebarPanel {}
                }
                Component {
                    UtilitiesPanel {}
                }

                // Taskbar component sub-pages
                Component {
                    BarWorkspaces {}
                }
                Component {
                    BarActiveWindow {}
                }
                Component {
                    BarTray {}
                }
                Component {
                    BarStatusIcons {}
                }
                Component {
                    BarClock {}
                }
            }
        },
        Component {
            // Keybinds
            StackPage {
                Component {
                    KeybindsPage {}
                }
            }
        },
        Component {
            // Apps
            StackPage {
                Component {
                    AppsPage {}
                }
                Component {
                    AllApps {}
                }
                Component {
                    AppInfo {}
                }
            }
        },
        Component {
            // Services
            StackPage {
                Component {
                    ServicesPage {}
                }
                Component {
                    NotificationsPage {}
                }
            }
        },
        Component {
            // Language & region
            StackPage {
                Component {
                    LanguageAndRegion {}
                }
                Component {
                    LayoutPicker {}
                }
                Component {
                    TimezonePicker {}
                }
            }
        },

        // About
        Component {
            StackPage {
                Component {
                    AboutPage {}
                }
            }
        }
    ]

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState // To avoid the warning from non-existent property

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
