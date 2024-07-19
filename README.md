# FelocordTweak

Tweak to inject [Felocord](https://github.com/Felocord/Felocord) into Discord. Forked [VendettaTweak](https://github.com/vendetta-mod/VendettaTweak), modified to match with [FelocordXposed](https://github.com/Felocord/Xposed) behavior. There are still slight differences between these two, and this tweak may be missing some loader features.

> [!NOTE]
> As of right now this tweak does not encompass some functionalities when running in a jailed environment with a wildcard certificate \
> If you value these features sign the application with a local dev certificate:
> - setAlternateAppIcon does not work, thus breaking dynamic app icons
> - sharing files to the application/selecting items via the Files app does not work 

## Installation

Builds can be found in the [Releases](https://github.com/Felocord/Tweak/releases/latest) tab.

> [!NOTE]
> Raw decrypted IPAs which are used to provide prepatched IPAs are sourced from the [Enmity](https://github.com/enmity-mod/) community. These raw decrypted IPAs are also used throughout Enmity related projects such as [enmity-mod/tweak](https://github.com/enmity-mod/tweak/) and [acquitelol/rosiecord](https://github.com/acquitelol/rosiecord).\
> All credits are attributed to the owner(s) of the raw IPAs.

### Jailbroken

1. Install the Orion runtime via your preferred package manager, by adding `https://repo.chariz.com/` to your sources, then finding `Orion Runtime`.
1. Install Felocord by downloading the appropriate Debian package (or by building your own, see [Building FelocordTweak locally](#building-felocordtweak-locally)) and adding it to your package manager. Use the file ending in `arm.deb` for rootful jailbreaks, and the file ending in `arm64.deb` for rootless jailbreaks.

### Jailed

<a href="https://tinyurl.com/24zjszuf"><img src="https://i.imgur.com/dsbDLK9.png" width="230"></a>
<a href="https://tinyurl.com/yh455zk6"><img src="https://i.imgur.com/46qhEAv.png" width="230"></a>

> [!NOTE]
> TrollStore may display an encryption warning, which you can disregard.

1. Download and install [Felocord.ipa](https://github.com/Felocord/Tweak/releases/latest/download/Felocord.ipa) using your preferred sideloading method.

## Building FelocordTweak locally

> [!NOTE]
> These steps assume you use MacOS.

1. Install Xcode from the App Store. If you've previously installed the `Command Line Utilities` package, you will need to run `sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer` to make sure you're using the Xcode tools instead.

> If you want to revert the `xcode-select` change, run `sudo xcode-select -switch /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`

2. Install the required dependencies. You can do this by running `brew install make ldid` in your terminal. If you do not have brew installed, follow the instructions [here](https://brew.sh/).

3. Setup your path accordingly. We recommend you run the following before running the next commands, as well as any time you want to build FelocordTweak.

```bash
export PATH="$(brew --prefix make)/libexec/gnubin:$PATH"
# feel free to set whatever path you want, but it needs to be a direct path, without relative parts
export THEOS="/Users/vendetta/IPA/theos"
```

4. Setup [theos](https://theos.dev/docs/installation-macos) by running the script provided by theos.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```

If you've already installed theos, you can run `$THEOS/bin/update-theos` to make sure it's up to date.

5. Clone this repository with `git clone git@github.com:Felocord/Tweak.git` and `cd` into it. Replace the URL with your fork if you've forked this repository.

6. To build FelocordTweak, you can run `rm -rf packages && make clean && make package FINALPACKAGE=1 && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`. The first command will remove any previous packages, the second will clean the project, the third will build the rootful package (which is denoted by the `arm.deb` ending), and the fourth will build the rootless package (which is denoted by the `arm64.deb` ending).

The first time you run this, it might take a bit longer, but subsequent builds should be much faster.

The resulting `.deb` files will be in the `packages` folder. As a reminder, `*arm.deb` is for rootful jailbreaks and sideloading, and `*arm64.deb` is for rootless jailbreaks.

## Contributing

If you want to contribute, you will basically need to follow the steps for [Building FelocordTweak locally](#building-felocordtweak-locally), as well as run `make spm` for the Swift LSP to work.

<!-- @vladdy was here, battling all these steps so you don't have to. Have fun! :3 -->
<!-- @castdrian also was here simplifying these steps immensely -->
