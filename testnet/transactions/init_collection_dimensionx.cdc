import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import DimensionX from 0x46664e2033f9853d

// This transaction is what an account would run
// to set itself up to receive NFTs

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