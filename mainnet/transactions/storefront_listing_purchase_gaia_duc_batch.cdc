import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import Gaia from 0x8b148183c28ff88f
import NFTStorefront from 0x4eb8a10cb9f87357

transaction(
    listingOwnerAddresses: [Address], 
    listingResourceIDs: [UInt64], 
    expectedPrices: [UFix64]
) {
    let mainDapperUtilityCoinVaultRef: &DapperUtilityCoin.Vault
    let ftBalanceBeforePurchase: UFix64

    prepare(dapper: AuthAccount, acct: AuthAccount) {
        assert(acct.address == 0xf8d6e0586b0a20c7, message: "Acct not authorized for txn")
        assert(listingResourceIDs.length == listingOwnerAddresses.length, message: "owner and listing counts mismatch")

        // create a new collection if the account doesn't have one
        if acct.borrow<&Gaia.Collection{NonFungibleToken.Receiver}>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection()
            acct.save(<-collection, to: Gaia.CollectionStoragePath)
            acct.link<&Gaia.Collection{NonFungibleToken.CollectionPublic, Gaia.CollectionPublic}>(
                Gaia.CollectionPublicPath,
                target: Gaia.CollectionStoragePath
            )
        }

        // borrow receiver's collection
        let gaiaCollectionReceiverRef = acct.borrow<&Gaia.Collection{NonFungibleToken.Receiver}>(
            from: Gaia.CollectionStoragePath
        ) ?? panic("Cannot borrow NFT collection receiver from account")

        // borrow mainDapperUtilityCoinVault from Dapper's account
        self.mainDapperUtilityCoinVaultRef = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.ftBalanceBeforePurchase = self.mainDapperUtilityCoinVaultRef.balance

        for i, addr in listingOwnerAddresses {
            // get storefront
            let storefront = 
                getAccount(addr)
                .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
                .borrow()
                ?? panic("Could not borrow Storefront from provided address")
            
            // get listing
            let listingResourceID = listingResourceIDs[i]
            let listing = 
                storefront.borrowListing(listingResourceID: listingResourceID)
                ?? panic("No Offer with that ID in Storefront")

            // ensure price is expected
            let price = listing.getDetails().salePrice
            let expectedPrice = expectedPrices[i]
            assert(
                price == expectedPrice, 
                message: "Actual price, ".concat(price.toString()).concat(", does not match expected, ").concat(expectedPrice.toString())
            )

            // purchase listing
            let nft <- listing.purchase(payment: <- self.mainDapperUtilityCoinVaultRef.withdraw(amount: price))

            // deposit token
            gaiaCollectionReceiverRef.deposit(token: <- nft)

            // cleanup storefront
            storefront.cleanup(listingResourceID: listingResourceID)
        }
    }

    // Check that all DUC was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVaultRef.balance == self.ftBalanceBeforePurchase: "DUC leakage"
    }
}