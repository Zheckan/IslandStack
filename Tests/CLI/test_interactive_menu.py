"""Exercise the public CLI in a pseudo-terminal without installing any apps.

Run after swift build: python3 -m unittest discover -s Tests/CLI -v
"""

import os
import pty
import re
import select
import subprocess
import tempfile
import termios
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class TerminalSession:
    def __init__(self, binary, arguments=()):
        self.master, self.slave = pty.openpty()
        self.original_mode = termios.tcgetattr(self.slave)
        self.output = b""
        self.directory = tempfile.TemporaryDirectory()
        self.process = subprocess.Popen(
            [str(binary), *arguments], cwd=self.directory.name,
            stdin=self.slave, stdout=self.slave, stderr=self.slave,
            env={**os.environ, "TERM": "xterm-256color"},
        )

    def wait_for(self, text):
        deadline = time.monotonic() + 15
        expected = text.encode()
        while expected not in self.output:
            if time.monotonic() >= deadline:
                raise AssertionError(f"Missing {text!r} in {self.output.decode(errors='replace')}")
            if select.select([self.master], [], [], 0.1)[0]:
                self.output += os.read(self.master, 65536)
            elif self.process.poll() is not None:
                raise AssertionError(f"CLI exited before {text!r}: {self.output!r}")

    def send(self, keys):
        os.write(self.master, keys)

    def close(self):
        if self.process.poll() is None:
            self.send(b"\x03")
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        os.close(self.master)
        os.close(self.slave)
        self.directory.cleanup()


class InteractiveMenuTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = subprocess.check_output(
            ["swift", "build", "--show-bin-path"], cwd=ROOT, text=True,
        ).strip()
        cls.binary = Path(path) / "islandstack"
        doctor = subprocess.check_output([str(cls.binary), "doctor"], text=True)
        cls.devices = re.findall(r"^(.+): ([A-F0-9-]{36}) \[", doctor, re.MULTILINE)
        if not cls.devices:
            raise unittest.SkipTest("Requires an eligible booted iPhone Simulator")

    def session(self, arguments=()):
        session = TerminalSession(self.binary, arguments)
        self.addCleanup(session.close)
        return session

    def assert_terminal_restored(self, session):
        restored = termios.tcgetattr(session.slave)
        original = session.original_mode.copy()
        # macOS sets this transient state bit when returning to canonical mode.
        restored[3] &= ~termios.PENDIN
        original[3] &= ~termios.PENDIN
        self.assertEqual(restored, original)

    def test_arrows_and_enter_choose_second_simulator(self):
        if len(self.devices) < 2:
            self.skipTest("Requires two booted iPhone Simulators")
        session = self.session()
        session.wait_for("Use ↑/↓")
        session.send(b"\x1b[B\r")
        session.wait_for(f"Selected: {self.devices[1][0]}")
        session.wait_for("How many helper apps?")
        session.send(b"\x1b")
        session.wait_for("Cancelled.")
        self.assertEqual(session.process.wait(timeout=5), 130)
        self.assert_terminal_restored(session)

    def test_count_arrows_wrap_and_enter_confirms_three(self):
        session = self.session(["install", "--device", self.devices[0][1]])
        session.wait_for("Use ↑/↓")
        session.send(b"\x1b[B\x1b[B\x1b[A\x1b[A\x1b[A\r")
        session.wait_for("Selected: 3 helper apps")
        # The temporary caller directory prevents the host from finding a project.
        session.wait_for("Run this command from an IslandStack source checkout.")
        self.assertEqual(session.process.wait(timeout=5), 1)
        self.assert_terminal_restored(session)

    def test_ctrl_c_cancels_and_restores_terminal(self):
        session = self.session(["install", "--device", self.devices[0][1]])
        session.wait_for("Use ↑/↓")
        session.send(b"\x03")
        session.wait_for("Cancelled.")
        self.assertEqual(session.process.wait(timeout=5), 130)
        self.assert_terminal_restored(session)

    def test_piped_input_keeps_numeric_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [str(self.binary), "install", "--device", self.devices[0][1]],
                input="4\n2\n", text=True, capture_output=True, cwd=directory,
            )
        self.assertIn("Enter a number from 1 to 3.", result.stdout)
        self.assertIn("Selected: 2 helper apps", result.stdout)
        self.assertIn("source checkout", result.stderr)
        self.assertEqual(result.returncode, 1)
