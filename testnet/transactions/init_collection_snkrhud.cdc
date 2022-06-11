import SNKRHUDNFT from 0x9a85ed382b96c857
import NonFungibleToken from 0x631e88ae7f1d7c20

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

