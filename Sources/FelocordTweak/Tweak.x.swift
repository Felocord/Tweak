import Orion
import FelocordTweakC
import os

let felocordLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "felocord")
let source = URL(string: "felocord")!

let install_prefix = String(cString: get_install_prefix())
let isJailbroken = FileManager.default.fileExists(atPath: "\(install_prefix)/Library/Application Support/FelocordTweak/FelocordPatches.bundle")

let felocordPatchesBundlePath = isJailbroken ? "\(install_prefix)/Library/Application Support/FelocordTweak/FelocordPatches.bundle" : "\(Bundle.main.bundleURL.path)/FelocordPatches.bundle"

class FileManagerLoadHook: ClassHook<FileManager> {
  func containerURLForSecurityApplicationGroupIdentifier(_ groupIdentifier: NSString?) -> URL? {
    os_log("containerURLForSecurityApplicationGroupIdentifier called! %{public}@ groupIdentifier", log: felocordLog, type: .debug, groupIdentifier ?? "nil")

    if (isJailbroken) {
      return orig.containerURLForSecurityApplicationGroupIdentifier(groupIdentifier)
    }

    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let lastPath = paths.last!
    return lastPath.appendingPathComponent("AppGroup")
  }
}

class LoadHook: ClassHook<RCTCxxBridge> {
  func executeApplicationScript(_ script: Data, url: URL, async: Bool) {
    os_log("executeApplicationScript called!", log: felocordLog, type: .debug)

    let loaderConfig = getLoaderConfig()

    let felocordPatchesBundle = Bundle(path: felocordPatchesBundlePath)!

    if let patchPath = felocordPatchesBundle.url(forResource: "payload-base", withExtension: "js") {
      let patchData = try! Data(contentsOf: patchPath)
      os_log("Executing payload base", log: felocordLog, type: .debug)
      orig.executeApplicationScript(patchData, url: source, async: true)
    }

    let felitendoDirectory = getFelitendoDirectory()

    var bundle = try? Data(contentsOf: felitendoDirectory.appendingPathComponent("bundle.js"))

    let group = DispatchGroup()

    group.enter()
    var bundleUrl: URL
    if loaderConfig.customLoadUrl.enabled {
      os_log(
        "Custom load URL enabled, with URL %{public}@ ", log: felocordLog, type: .info,
        loaderConfig.customLoadUrl.url.absoluteString)
      bundleUrl = loaderConfig.customLoadUrl.url
    } else {
      bundleUrl = URL(
        string: "https://raw.githubusercontent.com/Felocord/builds/main/felocord.js")!
    }

    os_log("Fetching JS bundle", log: felocordLog, type: .info)
    var bundleRequest = URLRequest(
      url: bundleUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 3.0)

    if let bundleEtag = try? String(
      contentsOf: felitendoDirectory.appendingPathComponent("etag.txt")), bundle != nil
    {
      bundleRequest.addValue(bundleEtag, forHTTPHeaderField: "If-None-Match")
    }

    let fetchTask = URLSession.shared.dataTask(with: bundleRequest) { data, response, error in
      if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
        os_log("Successfully fetched JS Bundle", log: felocordLog, type: .debug)
        bundle = data
        try? bundle?.write(to: felitendoDirectory.appendingPathComponent("bundle.js"))

        let etag = httpResponse.allHeaderFields["Etag"] as? String
        try? etag?.write(
          to: felitendoDirectory.appendingPathComponent("etag.txt"), atomically: true,
          encoding: .utf8)
      }

      group.leave()
    }

    fetchTask.resume()
    group.wait()

    if let themeString = try? String(
      contentsOf: felitendoDirectory.appendingPathComponent("current-theme.json"))
    {
      orig.executeApplicationScript(
        "globalThis.__PYON_LOADER__.storedTheme=\(themeString)".data(using: .utf8)!, url: source, async: async)
    }

    let preloadsDirectory = felitendoDirectory.appendingPathComponent("preloads")
  
    if FileManager.default.fileExists(atPath: preloadsDirectory.path) {
      do {
        let contents = try FileManager.default.contentsOfDirectory(
          at: preloadsDirectory, includingPropertiesForKeys: nil, options: [])
        
        for fileURL in contents {
          if fileURL.pathExtension == "js" {
            os_log(
              "Executing preload JS file %{public}@ ", log: felocordLog, type: .info, fileURL.absoluteString)
            
            if let data = try? Data(contentsOf: fileURL) {
              orig.executeApplicationScript(data, url: source, async: async)
            }
          }
        }
      } catch {
        os_log("Error reading contents of preloads directory", log: felocordLog, type: .error)
      }
    }

    if bundle != nil {
      os_log("Executing JS bundle", log: felocordLog, type: .info)
      orig.executeApplicationScript(bundle!, url: source, async: async)
    } else {
      os_log("Unable to fetch JS bundle", log: felocordLog, type: .error)
    }

    os_log("Executing original script", log: felocordLog, type: .info)
    orig.executeApplicationScript(script, url: url, async: async)
  }
}

struct FelocordTweak: Tweak {
  func tweakDidActivate() {
    if let themeData = try? Data(
    contentsOf: felitendoDirectory.appendingPathComponent("current-theme.json")) {
      let theme = try? JSONDecoder().decode(Theme.self, from: themeData)
      if let semanticColors = theme?.data.semanticColors { swizzleDCDThemeColor(semanticColors) }
      if let rawColors = theme?.data.rawColors { swizzleUIColor(rawColors) }
    }

    if let fontData = try? Data(
    contentsOf: felitendoDirectory.appendingPathComponent("fonts.json")) {
      let fonts = try? JSONDecoder().decode(FontDefinition.self, from: fontData)
      if let main = fonts?.main { patchFonts(main, fontDefName: fonts!.name) }
    }
  }
}
