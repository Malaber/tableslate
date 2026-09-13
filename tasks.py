from __future__ import annotations

import os
import shlex
from pathlib import Path

from invoke import task


ROOT = Path(__file__).resolve().parent
IOS_DIR = ROOT / "ios" / "TableSlateIOS"
DEFAULT_IPHONE = "iPhone 17 Pro"
DEFAULT_IPAD = "iPad Pro 13-inch (M5)"


def _ios_env() -> dict[str, str]:
    module_cache = IOS_DIR / ".clang-module-cache"
    module_cache.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    env.setdefault("CLANG_MODULE_CACHE_PATH", str(module_cache))
    return env


@task
def install_xcodegen(c) -> None:
    """Install XcodeGen through Homebrew when missing."""
    c.run(
        "brew list xcodegen >/dev/null 2>&1 || brew install xcodegen",
        pty=False,
        shell="/bin/bash",
    )


@task
def generate_ios_project(c) -> None:
    """Generate the ignored Xcode project from project.yml."""
    c.run(
        f"cd {shlex.quote(str(IOS_DIR))} && xcodegen generate",
        env=_ios_env(),
        pty=False,
        shell="/bin/bash",
    )


@task
def check_ios_package(c) -> None:
    """Run core tests and the configured line-coverage gate."""
    c.run(
        shlex.quote(str(IOS_DIR / "Scripts" / "check_coverage.sh")),
        env=_ios_env(),
        pty=False,
        shell="/bin/bash",
    )


@task(help={"device_name": "Exact installed iOS Simulator device name."})
def build_ios_simulator(c, device_name=DEFAULT_IPHONE) -> None:
    """Generate and compile TableSlate for an iOS simulator."""
    generate_ios_project.body(c)
    destination = f"platform=iOS Simulator,name={device_name},OS=latest"
    command = " ".join(
        [
            f"cd {shlex.quote(str(IOS_DIR))} &&",
            "xcodebuild -project TableSlateApp.xcodeproj -scheme TableSlate",
            f"-destination {shlex.quote(destination)} -destination-timeout 120",
            "-derivedDataPath .derived-data CODE_SIGNING_ALLOWED=NO build",
        ]
    )
    c.run(command, env=_ios_env(), pty=False, shell="/bin/bash")


@task(
    help={
        "device_name": "Exact installed iOS Simulator device name.",
        "artifact_dir": "Repo-relative result directory.",
    }
)
def ios_ui_e2e(c, device_name=DEFAULT_IPHONE, artifact_dir="e2e-artifacts/ios-iphone") -> None:
    """Run the XCUITest flows on one named simulator."""
    command = " ".join(
        [
            shlex.quote(str(IOS_DIR / "Scripts" / "run_ui_e2e.sh")),
            shlex.quote(device_name),
            shlex.quote(artifact_dir),
        ]
    )
    c.run(command, env=_ios_env(), pty=False, shell="/bin/bash")


@task(default=True)
def check(c) -> None:
    """Run the portable core gate."""
    check_ios_package.body(c)
