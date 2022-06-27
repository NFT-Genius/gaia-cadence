import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import AnchainUtils from 0x7ba45bdcac17806a
import MetaPanda from 0xf2af175e411dfff8

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&MetaPanda.Collection>(from: MetaPanda.CollectionStoragePath) == nil {
            let collection <- MetaPanda.createEmptyCollection()
            self.signer.save(<- collection, to: MetaPanda.CollectionStoragePath)
            self.signer.link<&{
                NonFungibleToken.CollectionPublic,
                MetadataViews.ResolverCollection,
                AnchainUtils.ResolverCollection
            }>(
                MetaPanda.CollectionPublicPath,
                target: MetaPanda.CollectionStoragePath
            )
        }
    }
}
