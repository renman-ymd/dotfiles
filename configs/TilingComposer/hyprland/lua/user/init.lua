-- Entry point. Home Manager require()s this file; it loads the rest in order.
-- apps, defs and util are loaded by the modules that need them.
require("user.settings")
require("user.rules")
require("user.workspaces")
require("user.floating")
require("user.layout")
require("user.keys")
require("user.gestures")
require("user.autostart")
