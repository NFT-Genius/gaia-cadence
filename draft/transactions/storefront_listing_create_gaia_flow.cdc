import FungibleToken from 0xFungibleToken
import NonFungibleToken from 0xNonFungibleToken
import DapperUtilityCoin from 0xDapperUtilityCoin
import Gaia from 0xGaia
import NFTStorefront from 0xNFTStorefront

// create Storefront listing that accepts DUC

transaction(saleItemID: UInt64, saleItemPrice: UFix64, setID: UInt64) {
    let ducReceiver: Capability<&{FungibleToken.Receiver}>
    let marketReceiver: Capability<&{FungibleToken.Receiver}>
    let GaiaProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let marketFee: UFix64
    let creatorFee: UFix64
    let marketAddress: Address

    prepare(acct: AuthAccount) {
        self.marketFee = 0.05
        self.creatorFee = 0.05
        self.marketAddress = 0xGaiaMarketplace
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let GaiaCollectionProviderPrivatePath = /private/GaiaCollectionProviderForNFTStorefront
        self.ducReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.ducReceiver.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin receiver")
        self.marketReceiver = getAccount(self.marketAddress).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(self.marketReceiver.borrow() != nil, message: "Missing or mis-typed DapperUtilityCoin receiver")

        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath)!.check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath, target: Gaia.CollectionStoragePath)
        }
        self.GaiaProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath)
        assert(self.GaiaProvider.borrow() != nil, message: "Missing or mis-typed Gaia.Collection provider")
        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
        let existingOffers = self.storefront.getListingIDs()
        if existingOffers.length > 0 {
            for listingResourceID in existingOffers {
                let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}? = self.storefront.borrowListing(listingResourceID: listingResourceID)
                if listing != nil && listing!.getDetails().nftID == saleItemID {
                    self.storefront.removeListing(listingResourceID: listingResourceID)
                }
            }
        }
    }

    execute {
        let marketCutAmount = saleItemPrice * self.marketFee
        let marketSaleCut = NFTStorefront.SaleCut(
            receiver: self.marketReceiver,
            amount: marketCutAmount,
        )
        let creatorCutAmount = saleItemPrice * self.creatorFee
        let creatorSaleCut = NFTStorefront.SaleCut(
            receiver: self.marketReceiver,
            amount: creatorCutAmount,
        )
        let sellerSaleCut = NFTStorefront.SaleCut(
            receiver: self.ducReceiver,
            amount: saleItemPrice - (marketCutAmount + creatorCutAmount),
        )
        self.storefront.createListing(
            nftProviderCapability: self.GaiaProvider,
            nftType: Type<@Gaia.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: [sellerSaleCut, marketSaleCut, creatorSaleCut],
        )
    }
}
