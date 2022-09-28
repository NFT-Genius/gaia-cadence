import DugoutDawgzNFT from 0x44eb6c679f0a4adc
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

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
