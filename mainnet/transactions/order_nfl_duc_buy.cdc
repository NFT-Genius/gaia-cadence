import GaiaOrder from 0x8b148183c28ff88f
import GaiaFee from 0x8b148183c28ff88f
import AllDay from 0xe4cf4bdc1751c65d
import NFTStorefront from 0x4eb8a10cb9f87357
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe

transaction (orderId: UInt64, storefrontAddress: Address, expectedPrice: UFix64) {
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let paymentVault: @FungibleToken.Vault
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let tokenReceiver: &AllDay.Collection{NonFungibleToken.CollectionPublic, AllDay.MomentNFTCollectionPublic}
    let buyerAddress: Address
    let price: UFix64
    let mainDapperUtilityCoinVault: &DapperUtilityCoin.Vault
    let balanceBeforeTransfer: UFix64

    prepare(dapper: AuthAccount, acct: AuthAccount, svcAcct: AuthAccount) {
        assert(svcAcct.address == 0x8b148183c28ff88f, message: "Must be signed by service account")

        self.storefront = getAccount(storefrontAddress)
            .getCapability(NFTStorefront.StorefrontPublicPath)!
            .borrow<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>()
            ?? panic("Could not borrow Storefront from provided address")

        self.listing = self.storefront.borrowListing(listingResourceID: orderId)
                    ?? panic("No Listing with that ID in Storefront")
        self.price = self.listing.getDetails().salePrice

        // Withdraw mainDapperUtilityCoinVault from Dapper's account
        self.mainDapperUtilityCoinVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: self.price)

        // create a new collection if the account doesn't have one
        if acct.borrow<&AllDay.Collection>(from: AllDay.CollectionStoragePath) == nil {
            let collection <- AllDay.createEmptyCollection()
            acct.save(<-collection, to: AllDay.CollectionStoragePath)
            acct.link<&AllDay.Collection{NonFungibleToken.CollectionPublic, AllDay.MomentNFTCollectionPublic}>(
                AllDay.CollectionPublicPath,
                target: AllDay.CollectionStoragePath
            )
        }

        self.tokenReceiver = acct.getCapability(AllDay.CollectionPublicPath)
            .borrow<&AllDay.Collection{NonFungibleToken.CollectionPublic, AllDay.MomentNFTCollectionPublic}>()
            ?? panic("Cannot borrow NFT collection receiver from acct")

        self.buyerAddress = acct.address
    }

    // Check that the price is right
    pre {
        self.price == expectedPrice: "unexpected price"
    }

    execute {
        let item <- GaiaOrder.closeOrder(
            storefront: self.storefront,
            orderId: orderId,
            orderAddress: storefrontAddress,
            listing: self.listing,
            paymentVault: <- self.paymentVault,
            buyerAddress: self.buyerAddress
        )
        self.tokenReceiver.deposit(token: <-item)
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "dapperUtilityCoin leakage"
    }
}