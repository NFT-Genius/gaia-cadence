import SNKRHUDNFT from 0x80af1db15aa6535a
import NonFungibleToken from 0x1d7e57aa55817448

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&SNKRHUDNFT.Collection>(from: SNKRHUDNFT.CollectionStoragePath) == nil {
            let collection <- SNKRHUDNFT.createEmptyCollection() as! @SNKRHUDNFT.Collection
            self.signer.save(<-collection, to: SNKRHUDNFT.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, SNKRHUDNFT.CollectionPublic}>(SNKRHUDNFT.CollectionPublicPath, target: SNKRHUDNFT.CollectionStoragePath)
        }
    }
}

