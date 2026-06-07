# dmgbuild settings for the Kright installer DMG. Builds a styled, "drag to
# Applications" window headlessly (no Finder scripting / Automation permission).
# Driven by env vars set in build-dmg.sh.
import os

application = os.environ["KRIGHT_APP"]            # path to Kright.app
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
background = os.environ["KRIGHT_DMG_BG"]          # 660×440 PNG

# Window + icon layout (matches the arrow in the background image).
window_rect = ((200, 120), (660, 440))
default_view = "icon-view"
icon_size = 128
text_size = 13
icon_locations = {
    appname: (180, 250),
    "Applications": (480, 250),
}

# Clean, chrome-free installer window.
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
