# Contributing

Issues and pull requests are welcome. Describe the macOS version, Mac architecture,
steps to reproduce, and expected behavior. Keep screenshots and fixtures synthetic;
never attach private clipboard history, timer state, credentials or signing material.

Requires an Apple Silicon Mac with macOS 26+ and Xcode Command Line Tools.

Run the checks before submitting a change:

    sh scripts/test.sh
    sh scripts/build.sh

Native UI and sound checks belong in an isolated macOS VM. Mute the VM before
starting a timer or playing a sound. Do not test against a real clipboard database.
Keep the interface native, keyboard-first, and consistent with the glass styling.

CI runs the model/unit checks, a build, and ad-hoc bundle validation on macOS 26.
It has no signing credentials. Official release signing runs separately.

Contributions are under the repository's MIT license.
