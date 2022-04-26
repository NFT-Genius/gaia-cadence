import GaiaNFT from "../GaiaNFT.cdc"
import MetadataViews from "../../../../core/contract/MetadataViews.cdc"

pub contract GaiaStandardMetadata {
  pub struct IPFSMetadataWithDisplay: GaiaNFT.GaiaMetadata {
    pub let _display: MetadataViews.Display
    pub let metadataFile: {MetadataViews.File}
    
    pub fun hash(): [UInt8] {
      let data = ([] as [UInt8])
        .concat(HashAlgorithm.SHA3_256.hash(self.display().name.utf8))
        .concat(HashAlgorithm.SHA3_256.hash(self.display().description.utf8))
        .concat(HashAlgorithm.SHA3_256.hash(self.display().thumbnail.uri().utf8))
        .concat(HashAlgorithm.SHA3_256.hash(self.metadataFile.uri().utf8))
      return HashAlgorithm.SHA3_256.hash(data)
    }

    pub fun display(): MetadataViews.Display {
      return self._display
    }
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return self.display()
      }
      return nil
    }

    pub fun repr(): {String: String} {
      return {
        "uri": self.metadataFile.uri()
      }
    }

    init(display: MetadataViews.Display, metadataFile: {MetadataViews.File}) {
      self._display = display
      self.metadataFile = metadataFile
    }
  }

  pub struct GenericOnChainWithDisplay: GaiaNFT.GaiaMetadata {
    pub let _display: MetadataViews.Display
    pub let metadata: {String: String}
    pub let keys: [String]
    
    pub fun hash(): [UInt8] {
      var data = ([] as [UInt8])
        .concat(HashAlgorithm.SHA3_256.hash(self.display().name.utf8))
        .concat(HashAlgorithm.SHA3_256.hash(self.display().description.utf8))
        .concat(HashAlgorithm.SHA3_256.hash(self.display().thumbnail.uri().utf8))

      // get dict values in key order
      for key in self.keys {
        let val = self.metadata[key]!
        data = data
          .concat(HashAlgorithm.SHA3_256.hash(key.utf8))
          .concat(HashAlgorithm.SHA3_256.hash(val.utf8))
      }

      return HashAlgorithm.SHA3_256.hash(data)
    }

    pub fun display(): MetadataViews.Display {
      return self._display
    }
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return self.display()
      }
      return nil
    }
    
    pub fun repr(): {String: String} {
      return self.metadata
    }


    init(display: MetadataViews.Display, metadata: {String: String}, keys: [String]) {
      pre {
        metadata.length == keys.length: "Metadata and Key lengths mismatch"
      }
      self._display = display
      self.metadata = metadata
      self.keys = keys
    }
  }

}
