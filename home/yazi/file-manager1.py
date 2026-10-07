"""org.freedesktop.FileManager1 for a file manager with no D-Bus side.

Firefox, Chromium, Electron and Qt apps and the desktop portal call
ShowItems for "Show in folder". Each call runs the command given as this
program's arguments with the paths appended. D-Bus starts the program when
the name is first called (the service file is in ./file-manager.nix), and
it leaves after a quiet half minute.
"""
import asyncio
import os
import subprocess
import sys
from urllib.parse import unquote_to_bytes

from dbus_fast.aio import MessageBus
from dbus_fast.service import ServiceInterface, method

NAME = "org.freedesktop.FileManager1"
QUIET_SECONDS = 30


def path_of(uri):
    """The path a file:// URI names, byte for byte; None for any other URI.

    Everything after the host is the path: a file URI has no query and no
    fragment, so a caller that left a "?" or a "#" unescaped meant the name.
    """
    if not uri.startswith("file://"):
        return None
    start = uri.find("/", len("file://"))
    if start < 0:
        return None
    return os.fsdecode(unquote_to_bytes(uri[start:]))


class FileManager(ServiceInterface):
    def __init__(self, command, called):
        super().__init__(NAME)
        self.command = command
        self.called = called

    def show(self, uris):
        self.called()
        paths = [path for path in map(path_of, uris) if path]
        if paths:
            subprocess.Popen([*self.command, *paths])

    @method()
    def ShowFolders(self, uris: "as", startup_id: "s"):
        self.show(uris)

    @method()
    def ShowItems(self, uris: "as", startup_id: "s"):
        self.show(uris)

    @method()
    def ShowItemProperties(self, uris: "as", startup_id: "s"):
        self.show(uris)


async def main(command):
    loop = asyncio.get_running_loop()
    quiet = loop.create_future()
    timer = None

    def called():
        nonlocal timer
        if timer:
            timer.cancel()
        timer = loop.call_later(QUIET_SECONDS, quiet.set_result, None)

    bus = await MessageBus().connect()
    bus.export("/org/freedesktop/FileManager1", FileManager(command, called))
    await bus.request_name(NAME)
    called()
    await quiet


if __name__ == "__main__":
    asyncio.run(main(sys.argv[1:]))
