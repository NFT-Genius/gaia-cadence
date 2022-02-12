import GaiaOrder from 0xdaabc8918ed8cf52
import GaiaFee from 0xdaabc8918ed8cf52
import NFTStorefront from 0x94b06cfca1d8a476

transaction(orderId: UInt64) {
    prepare(acct: AuthAccount) {
        let storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
        let listing = storefront.borrowListing(listingResourceID: orderId)!

        GaiaOrder.removeOrder(
            storefront: storefront,
            orderId: orderId,
            orderAddress: acct.address,
            listing: listing
        )
   }
}