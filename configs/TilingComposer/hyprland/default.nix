# Hyprland 0.56 (Lua config) for Home Manager.
#
# Import this file from your Home Manager user config. The NixOS side
# (`programs.hyprland.enable = true;`) installs Hyprland itself, which is why
# `package` and `portalPackage` are null here, as Home Manager's docs ask.
{ lib, ... }:
let
  # Helper modules, loaded by user/init.lua with require(), never auto-loaded.
  helpers = [
    "apps"
    "defs"
    "util"
    "settings"
    "rules"
    "workspaces"
    "floating"
    "layout"
    "keys"
    "gestures"
    "autostart"
  ];

  helperFile = name:
    lib.nameValuePair "user.${name}" {
      content = ./lua/user + "/${name}.lua";
      autoLoad = false;
    };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";

    extraLuaFiles = lib.listToAttrs (map helperFile helpers) // {
      # The only file Home Manager require()s from hyprland.lua.
      "user.init" = {
        content = ./lua/user/init.lua;
        autoLoad = true;
      };
    };
  };
}
