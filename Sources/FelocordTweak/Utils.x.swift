import Foundation

func getFelitendoDirectory() -> URL {
  let documentDirectoryURL = try! FileManager.default.url(
      for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
  
  let felitendoFolderURL = documentDirectoryURL.appendingPathComponent("felitendo")
  
  // Create the "felitendo" folder if it doesn't exist
  if !FileManager.default.fileExists(atPath: felitendoFolderURL.path) {
      try! FileManager.default.createDirectory(
        at: felitendoFolderURL, withIntermediateDirectories: true, attributes: nil)
  }
  
  return felitendoFolderURL
}
