import BarterYardClubWerewolf from 0x195caada038c5806
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&BarterYardClubWerewolf.Collection>(from: BarterYardClubWerewolf.CollectionStoragePath) == nil {
            // create a new empty collection
            let collection <- BarterYardClubWerewolf.createEmptyCollection()

            // save it to the account
            self.signer.save(<-collection, to: BarterYardClubWerewolf.CollectionStoragePath)

            // create a public capability for the collection
            self.signer.link<&BarterYardClubWerewolf.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
                (BarterYardClubWerewolf.CollectionPublicPath, target: BarterYardClubWerewolf.CollectionStoragePath)
        }
    }
}

