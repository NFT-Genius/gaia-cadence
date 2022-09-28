import DugoutDawgzNFT from 0xd527bd7a74847cc7
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&DugoutDawgzNFT.Collection>(from: DugoutDawgzNFT.CollectionStoragePath) == nil {
            let collection <- DugoutDawgzNFT.createEmptyCollection() as! @DugoutDawgzNFT.Collection
            self.signer.save(<-collection, to: DugoutDawgzNFT.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, DugoutDawgzNFT.CollectionPublic, MetadataViews.ResolverCollection}>
                (DugoutDawgzNFT.CollectionPublicPath, target: DugoutDawgzNFT.CollectionStoragePath)
        }
    }
}
