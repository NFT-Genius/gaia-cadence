import GaiaOrder from 0x8b148183c28ff88f
import GaiaFee from 0x8b148183c28ff88f
import NFTStorefront from 0x4eb8a10cb9f87357

transaction(nftID: UInt64) {
    let storefront: &NFTStorefront.Storefront
    let orderAddress: Address
    let listings: [&NFTStorefront.Listing{NFTStorefront.ListingPublic}]

    prepare(acct: AuthAccount) {
        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        self.orderAddress = acct.address


        // find all existing listings with matching nft id 
        self.listings = []
        let listingIDs = self.storefront.getListingIDs()
        for id in listingIDs {
            let listing = self.storefront.borrowListing(listingResourceID: id)! 
            if listing.getDetails().nftID == nftID {
                self.listings.append(listing)
            }
        }
        assert(self.listings.length > 0, message: "no listings for nft id")
    }

    execute {
        // remove listings
        for listing in self.listings {
            GaiaOrder.removeOrder(
                storefront: self.storefront,
                orderId: listing.uuid,
                orderAddress: self.orderAddress,
                listing: listing
            )
        }
    }
}
