import GaiaOrder from 0xdaabc8918ed8cf52
import NFTStorefront from 0x94b06cfca1d8a476
import AllDay from 0x4dfd62c88d1b6462

transaction(nftID: UInt64) {
    let storefront: &NFTStorefront.Storefront
    let orderAddress: Address
    let listings: [&NFTStorefront.Listing{NFTStorefront.ListingPublic}]

    prepare(acct: AuthAccount) {
        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        self.orderAddress = acct.address

        // find all existing listings with matching nft id and matching type 
        self.listings = []
        let listingIDs = self.storefront.getListingIDs()
        for id in listingIDs {
            let listing = self.storefront.borrowListing(listingResourceID: id)! 
            let details = listing.getDetails()
            if details.nftID == nftID && 
                details.nftType == Type<@AllDay.NFT>() {
                self.listings.append(listing)
            }
        }
        assert(self.listings.length > 0, message: "no listings for nft id")
    }

    execute {
        // remove orders
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