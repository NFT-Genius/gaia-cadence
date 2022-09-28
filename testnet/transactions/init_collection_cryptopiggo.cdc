import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import CryptoPiggo from 0x57e1b27618c5bb69

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&CryptoPiggo.Collection>(from: CryptoPiggo.CollectionStoragePath) == nil {
            let collection <- CryptoPiggo.createEmptyCollection() as! @CryptoPiggo.Collection
            self.signer.save(<-collection, to: CryptoPiggo.CollectionStoragePath)
            self.signer.link<&CryptoPiggo.Collection{CryptoPiggo.CryptoPiggoCollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(CryptoPiggo.CollectionPublicPath, target: CryptoPiggo.CollectionStoragePath)
        }
    }
}

