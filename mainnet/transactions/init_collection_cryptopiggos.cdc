import CryptoPiggo from 0xd3df824bf81910a4
import NonFungibleToken from 0x1d7e57aa55817448

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
