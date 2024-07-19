import Foundation
import os

enum LoaderConfigError: Error {
  case doesNotExist
}

struct CustomLoadUrl: Codable {
  let enabled: Bool
  let url: URL
}

struct LoaderConfig: Codable {
  let customLoadUrl: CustomLoadUrl
}

let defaultLoaderConfig = LoaderConfig(
  customLoadUrl: CustomLoadUrl(
    enabled: false,
    url: URL(string: "http://localhost:4040/felocord.js")!
  )
)

let felitendoDirectory = getFelitendoDirectory()
let loaderConfigUrl = felitendoDirectory.appendingPathComponent("loader.json")

func getLoaderConfig() -> LoaderConfig {
  os_log("Getting loader config", log: felocordLog, type: .debug)
  let fileManager = FileManager.default

  do {
    if fileManager.fileExists(atPath: loaderConfigUrl.path) {
      let data = try Data(contentsOf: loaderConfigUrl)
      let loaderConfig = try JSONDecoder().decode(LoaderConfig.self, from: data)

      os_log("Got loader config", log: felocordLog, type: .debug)

      return loaderConfig
    } else {
      throw LoaderConfigError.doesNotExist
    }
  } catch {
    os_log("Couldn't get loader config", log: felocordLog, type: .error)

    return defaultLoaderConfig
  }
}
