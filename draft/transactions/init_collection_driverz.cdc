import DriverzNFT from 0xDriverzNFT
import NonFungibleToken from 0xNonFungibleToken
import MetadataViews from 0xMetadataViews

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&DriverzNFT.Collection>(from: DriverzNFT.CollectionStoragePath) == nil {
            let collection <- DriverzNFT.createEmptyCollection() as! @DriverzNFT.Collection
            self.signer.save(<-collection, to: DriverzNFT.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, DriverzNFT.CollectionPublic, MetadataViews.ResolverCollection}>
                (DriverzNFT.CollectionPublicPath, target: DriverzNFT.CollectionStoragePath)
        }
    }
}

