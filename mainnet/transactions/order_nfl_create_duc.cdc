import GaiaOrder from 0x8b148183c28ff88f
import GaiaFee from 0x8b148183c28ff88f
import AllDay from 0xe4cf4bdc1751c65d
import NFTStorefront from 0x4eb8a10cb9f87357
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe

transaction(nftID: UInt64, price: UFix64) {
    let nftProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let oldListings: [&NFTStorefront.Listing{NFTStorefront.ListingPublic}]
    let orderAddress: Address

    prepare(acct: AuthAccount) {
        // verify/init nft provider
        let nftProviderPath = /private/AllDayNFTProviderForNFTStorefront
        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftProviderPath)!.check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftProviderPath, target: AllDay.CollectionStoragePath)
        }
        self.nftProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(nftProviderPath)!
        assert(self.nftProvider.borrow() != nil, message: "Missing or mis-typed nft collection provider")

        // verify/init storefront
        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            let storefront <- NFTStorefront.createStorefront() as! @NFTStorefront.Storefront
            acct.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }
        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        // order address same as proposer
        self.orderAddress = acct.address

        // verify duc vault 
        assert(acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver).check(), message: "Cannot borrow DapperUtilityCoin vault from acct storage")

        // find all existing listings with matching nft id 
        self.oldListings = []
        let listingIDs = self.storefront.getListingIDs()
        for id in listingIDs {
            let listing = self.storefront.borrowListing(listingResourceID: id)! 
            if listing.getDetails().nftID == nftID {
                self.oldListings.append(listing)
            }
        }
    }

    execute {
        // remove old listings
        for listing in self.oldListings {
            GaiaOrder.removeOrder(
                storefront: self.storefront,
                orderId: listing.uuid,
                orderAddress: self.orderAddress,
                listing: listing
            )
        }

        let royalties: [GaiaOrder.PaymentPart] = []
        let extraCuts: [GaiaOrder.PaymentPart] = []

        // specify fees for AllDay (this is secure because all txs must be whitelisted by Dapper)
        let feeRecipientAddress: Address = 0xe4cf4bdc1751c65d 
        let feePercentage = 0.05

        royalties.append(GaiaOrder.PaymentPart(address: feeRecipientAddress, rate: feePercentage))

        GaiaOrder.addOrder(
            storefront: self.storefront,
            nftProvider: self.nftProvider,
            nftType: Type<@AllDay.NFT>(), // specify nft type
            nftId: nftID,
            vaultPath: /public/dapperUtilityCoinReceiver, // specify public ft vault path
            vaultType: Type<@DapperUtilityCoin.Vault>(), // specify ft token
            price: price,
            extraCuts: extraCuts,
            royalties: royalties
        )
    }
}