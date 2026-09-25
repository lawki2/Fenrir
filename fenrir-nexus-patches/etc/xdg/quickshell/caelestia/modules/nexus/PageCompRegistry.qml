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
import qs.modules.nexus.pages.lookandfeel
import qs.modules.nexus.pages.monitors
import qs.modules.nexus.pages.mouse
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

    // Same order as PageRegistry.pages.
    readonly property list<Component> pageComps: [
        // Personalise
        Component {
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
            StackPage {
                Component {
                    LookAndFeelPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    DesktopPage {}
                }
            }
        },
        Component {
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

        // Display
        Component {
            StackPage {
                Component {
                    MonitorsPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    NightLightPage {}
                }
            }
        },

        // Network
        Component {
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
            StackPage {
                Component {
                    FirewallPage {}
                }
            }
        },

        // Devices
        Component {
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
            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    PrintersPage {}
                }
            }
        },

        // Input
        Component {
            StackPage {
                Component {
                    MouseAndTouchpadPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    KeybindsPage {}
                }
            }
        },
        Component {
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

        // Apps
        Component {
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
            StackPage {
                Component {
                    NotificationsPage {
                        isSubPage: false
                    }
                }
            }
        },

        // System
        Component {
            StackPage {
                Component {
                    PowerPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    UpdatesPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    ServicesPage {
                        title: qsTr("Advanced")
                    }
                }
                Component {
                    NotificationsPage {}
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
