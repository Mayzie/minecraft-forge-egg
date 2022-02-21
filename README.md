# Pterodactyl Minecraft CurseForge Egg

Written for [Pterodactyl Server Management](https://pterodactyl.io/).

Install the egg by downloading the JSON file and importing it into a nest within your Pterodactyl control panel.

## Notes:

* This script only downloads and unpacks the modpacks from CurseForge, **it does not install them**. The reason for this
is because nowadays some modpacks seem to have their own unique installation method, and catering to them all is
unwieldy. Most modpacks will include their own uniquely named `.sh` script to run to install.
* The egg makes references to non-existent Docker containers. These are my own personalised Docker containers for my
Minecraft installations. Change them out as necessary.
