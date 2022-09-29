import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import DimensionX from 0xe3ad6030cbaff1c2

transaction {

    prepare(signer: AuthAccount) {
        // Return early if the account already has a collection
        if signer.borrow<&DimensionX.Collection>(from: DimensionX.CollectionStoragePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- DimensionX.createEmptyCollection()

        // save it to the account
        signer.save(<-collection, to: DimensionX.CollectionStoragePath)

        // create a public capability for the collection
        signer.link<&DimensionX.Collection{NonFungibleToken.CollectionPublic, DimensionX.CollectionPublic, MetadataViews.ResolverCollection}>(
            DimensionX.CollectionPublicPath,
            target: DimensionX.CollectionStoragePath
        )
    }
}
