-- Fenrir's Hyprland config lives in /usr/share/fenrir/hypr and updates with the system.
-- This folder is searched first, so a file here with a shipped file's name replaces it.
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;/usr/share/fenrir/hypr/?.lua;" .. package.path
dofile("/usr/share/fenrir/hypr/hyprland.lua")
