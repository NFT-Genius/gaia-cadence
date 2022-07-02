import CryptoPiggo from 0x57e1b27618c5bb69
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&CryptoPiggo.Collection>(from: CryptoPiggo.CollectionStoragePath) == nil {
            let collection <- CryptoPiggo.createEmptyCollection() as! @CryptoPiggo.Collection
            self.signer.save(<-collection, to: CryptoPiggo.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, CryptoPiggo.CryptoPiggoCollectionPublic}>(CryptoPiggo.CollectionPublicPath, target: CryptoPiggo.CollectionStoragePath)
        }
    }
}
