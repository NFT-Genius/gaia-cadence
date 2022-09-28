import AnchainUtils from 0x26e7006d6734ba69
import MetaPanda from 0x26e7006d6734ba69
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

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
