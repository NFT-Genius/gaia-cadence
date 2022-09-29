import SNKRHUDNFT from 0xf3fcd2c1a78f5eee
import NonFungibleToken from 0x01cf0e2f2f715450
import MetadataViews from 0x01cf0e2f2f715450

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&SNKRHUDNFT.Collection>(from: SNKRHUDNFT.CollectionStoragePath) == nil {
            let collection <- SNKRHUDNFT.createEmptyCollection() as! @SNKRHUDNFT.Collection
            self.signer.save(<-collection, to: SNKRHUDNFT.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, SNKRHUDNFT.CollectionPublic, MetadataViews.ResolverCollection}>
                (SNKRHUDNFT.CollectionPublicPath, target: SNKRHUDNFT.CollectionStoragePath)
        }
    }
}

