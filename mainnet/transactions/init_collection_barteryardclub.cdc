import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import BarterYardClubWerewolf from 0x28abb9f291cadaf2

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
